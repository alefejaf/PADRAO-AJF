# DEPLOY-STANDARD.md

## Visão geral

```
git push
  ↓
GitHub Actions: install → lint → test → build
  ↓
GitHub Actions: docker build → push para GHCR (tags: latest + SHA do commit)
  ↓
Servidor Docker (TrueNAS hoje, qualquer host Docker amanhã)
  ↓
Cloudflare Tunnel (ou outro reverse proxy) → HTTPS público
```

A aplicação **nunca** sabe que está atrás de Cloudflare — ela só escuta numa porta HTTP interna
(`web:3000`, `api:3001`). TLS e domínio público são responsabilidade da infraestrutura em
volta, não do container.

## Docker

Todo projeto com Web ou API nasce pronto para Docker:

- Dockerfile **multi-stage** (build isolado da imagem final de runtime).
- Imagem final reduzida (Next.js usa `output: "standalone"` **dentro do Docker**; API usa `pnpm deploy --prod`).
- `.dockerignore` cobrindo `node_modules`, `.env`, testes, `.git`.
- Usuário não-root na imagem final.
- `NODE_ENV=production` na imagem de runtime.
- Logs em stdout/stderr.
- `HEALTHCHECK` no Dockerfile.
- `restart: unless-stopped` no compose.
- Rede própria (`{{PROJECT_SLUG}}-network`), sem depender de IP fixo.
- Volumes só quando necessários (banco, uploads).
- Configuração inteira via variável de ambiente — nenhum secret dentro da imagem.

Ver [`NAMING-STANDARD.md`](./NAMING-STANDARD.md) para nomes de imagem/rede/volume (o compose
gerado não define `container_name:` — ver a justificativa lá).

## Build local x build de produção

`apps/web` builda de dois jeitos diferentes, de propósito:

| | Comando | Output do Next.js | Onde roda |
|---|---|---|---|
| **Local** (dev, CI, `pnpm run build` direto) | `pnpm run build` | padrão (`.next/`, sem `standalone`) | Windows, Linux, Mac — qualquer host |
| **Produção** (imagem Docker) | mesmo `pnpm run build`, mas com `NEXT_OUTPUT_STANDALONE=true` definida pelo Dockerfile antes de rodar | `standalone` (`.next/standalone/`) | Sempre dentro do container Linux do build multi-stage |

**Por quê:** `output: "standalone"` faz o Next.js copiar as dependências de produção
rastreadas para `.next/standalone` — essa cópia usa **symlinks**. Dentro do Dockerfile (Linux)
isso é transparente. Rodando `pnpm run build` direto num Windows sem privilégio de symlink (sem
PowerShell como Administrador, sem Developer Mode do Windows habilitado — nenhum dos dois é
exigido por este padrão), essa etapa de cópia falha com:

```
EPERM: operation not permitted, symlink
```

mesmo com a compilação do Next.js em si tendo funcionado normalmente. `templates/web/next.config.mjs`
só ativa `output: "standalone"` quando a variável de ambiente `NEXT_OUTPUT_STANDALONE` é
exatamente `"true"`:

```js
const isStandalone = process.env.NEXT_OUTPUT_STANDALONE === "true";

const nextConfig = {
  ...(isStandalone ? { output: "standalone" } : {}),
  // ...
};
```

E só `apps/web/Dockerfile` define essa variável, só no estágio de build, só antes de buildar:

```dockerfile
ENV NEXT_OUTPUT_STANDALONE=true
RUN pnpm --filter {{PROJECT_SLUG}}-web run build
```

Resultado: `pnpm run build` local nunca precisa de symlink (funciona em qualquer SO, sem
privilégio especial); a imagem Docker de produção continua exatamente tão otimizada quanto
antes (`output: "standalone"`, sem devDependencies, sem o resto do monorepo). O
`ci.yml` do GitHub Actions roda o build **normal** (sem standalone) só como gate de
sanidade — quem valida o build de produção de verdade é o `docker build` do
`docker-publish.yml`, que sempre roda em runner Linux e sempre passa por essa mesma etapa de
symlink sem problema:

```
pnpm install → lint → typecheck → test → build (normal)
  ↓
docker build → NEXT_OUTPUT_STANDALONE=true → next build → .next/standalone
```

## Variáveis de ambiente: raiz x por app

`docker-compose.yml` **não** usa `env_file:` apontando para os `.env` de cada app. Em vez
disso, cada serviço declara sua config em `environment:` usando `${VAR:-padrão}`, e o `docker
compose` carrega automaticamente o `.env` da **raiz** do projeto (`cp .env.example .env`) para
preencher essas variáveis. Isso significa:

- `docker compose config` funciona **imediatamente** depois de gerar o projeto, mesmo sem
  nenhum `.env` real ainda existir — nada de erro "arquivo não encontrado".
- A única exceção é o que é genuinamente obrigatório por segurança (`POSTGRES_PASSWORD` no
  modo `embedded`, `DATABASE_URL` no modo `external`) — esses usam `${VAR:?mensagem}` e o
  compose para com um erro claro e acionável até você definir o valor no `.env`.
- Os `.env`/`.env.local` **dentro** de `apps/web`, `apps/api`, `packages/database` continuam
  existindo — são para `pnpm run dev` **sem** Docker, lidos diretamente pelo Next.js/tsx/dotenv,
  não pelo `docker compose`.

## Portas e exposição da API

A porta **interna** do container nunca muda (`web:3000`, `api:3001` — é o que o Dockerfile e o
healthcheck esperam). O que `-WebPort`/`-ApiPort` do gerador controlam é só o mapeamento para o
**host**, para não colidir quando várias stacks PADRAO-AJF rodam no mesmo servidor:

```
Web  interna: 3000   host: 3100   (ex.: -WebPort 3100)
API  interna: 3001   host: 3101   (ex.: -ApiPort 3101)
```

A API só publica porta no host quando `-PublicApi` está ativo (automático quando há Mobile).
Sem consumidor externo, a API fica só em `expose:` — alcançável pelo `web` do mesmo compose via
rede Docker interna, mas invisível fora do host:

```yaml
# PublicApi = false (Web é o único consumidor, mesmo compose)
api:
  expose:
    - "3001"          # sem "ports:" — não publicado no host

# PublicApi = true (Mobile e/ou integração externa)
api:
  ports:
    - "3101:3001"     # publicado no host na porta escolhida (-ApiPort)
```

## Client-side x server-side: qual URL de API usar

Quando `apps/web` e `apps/api` existem, o Web tem duas variáveis para a mesma API — cada uma
resolve num contexto diferente e **não são intercambiáveis**:

| Variável | Roda em | Pode ser | Nunca pode ser |
|---|---|---|---|
| `NEXT_PUBLIC_API_URL` | **Browser** do usuário | URL pública HTTPS (`https://api-slug.exemplo.com.br`) | `http://api:3001` (só existe na rede Docker) |
| `API_INTERNAL_URL` | **Servidor** Next.js (Server Actions/Route Handlers/Server Components) | `http://api:3001` (endereço interno do compose) | — |

Uma configuração que funciona no servidor mas quebra no navegador (ou vice-versa) é o erro mais
comum aqui — ver `templates/web/src/lib/api-url.ts` para o helper que já resolve isso
corretamente (`API_INTERNAL_URL` no servidor, com fallback para `NEXT_PUBLIC_API_URL`).

O mesmo vale para o app mobile: ele nunca roda dentro da rede Docker do projeto, então
`EXPO_PUBLIC_API_URL` em produção **sempre** precisa ser a URL pública HTTPS — nunca
`localhost`, nunca `http://api:3001`.

## Versionamento de imagens

**Nunca depender só de `latest`.** Toda imagem publicada recebe no mínimo duas tags:

```
ghcr.io/{{GHCR_OWNER}}/{{PROJECT_SLUG}}-web:latest
ghcr.io/{{GHCR_OWNER}}/{{PROJECT_SLUG}}-web:<SHA-do-commit>
```

E, ao criar uma tag Git semântica (`v1.0.0`), o workflow também publica:

```
ghcr.io/{{GHCR_OWNER}}/{{PROJECT_SLUG}}-web:v1.0.0
```

Em produção, prefira sempre referenciar a imagem por **SHA ou versão semântica**, nunca só
`latest` — `latest` é conveniente para desenvolvimento, mas não é uma referência estável (o que
"`latest`" aponta para muda a cada build).

## GitHub Actions

Todo projeto gerado já vem com dois workflows (`.github/workflows/`):

- **`ci.yml`** — `scripts/validate-standard.ps1` (para o job com `FAIL`; `WARN` só aparece no
  log) → install → lint → typecheck → test → build, em todo push/PR. Usa
  `pnpm -r --if-present run <script>`, então funciona igual não importa quais apps o projeto
  tem.
- **`docker-publish.yml`** — roda `validate-standard.ps1` primeiro em cada job (um `FAIL`
  impede a publicação da imagem) e builda/publica no GHCR **só** as imagens cujo Dockerfile
  existe no repositório (checagem em runtime via `[ -f apps/web/Dockerfile ]`). Publica `web`
  e/ou `api`, nunca `mobile` (ver abaixo). Usa `secrets.GITHUB_TOKEN` — nenhum secret adicional
  é necessário para publicar no GHCR do próprio repositório.

Fluxo completo:

```
git push
  ↓
validate-standard.ps1  (FAIL para o build; WARN só avisa)
  ↓
pnpm install → lint → typecheck → test → build
  ↓
docker build → push para GHCR (latest + SHA)
```

## Mobile não vai para o GHCR

Aplicativo mobile não é uma imagem Docker — é buildado e distribuído via **EAS Build**
(Expo). Ver `apps/mobile/README.md` no projeto gerado para o passo a passo (`eas build`,
`eas submit`).

## Rollback

Nunca considere `latest` suficiente para recuperação — ele muda a cada deploy. A estratégia de
rollback é sempre baseada em **tag conhecida (SHA ou versão)**:

```
Produção está rodando: abc123
Novo deploy:            def456   ← problema identificado

Rollback:
1. Editar docker-compose.yml (ou o comando de deploy) trocando a tag da imagem
   de :def456 (ou :latest) para :abc123
2. docker compose pull
3. docker compose up -d
4. Confirmar healthcheck e smoke test (ver TESTING-STANDARD.md)
```

Checklist de rollback:

- [ ] a tag anterior (`abc123`) ainda existe no GHCR (imagens antigas não foram limpas por engano);
- [ ] o rollback do banco (se a migration do deploy problemático já rodou) foi avaliado — nem toda migration é revertível sem perda de dado, por isso migrations destrutivas exigem análise manual (ver `DATABASE-STANDARD.md`);
- [ ] depois do rollback, healthcheck e smoke test voltaram a passar;
- [ ] o incidente foi registrado (o que quebrou, por quê) antes de tentar o próximo deploy.

### Rastreando a versão em produção

`latest` não diz qual código está rodando agora nem qual rodava antes. Anote a tag real (SHA ou
versão semântica) de cada deploy bem-sucedido — um comentário no histórico de deploys, um
arquivo local não versionado no servidor (`infra/CURRENT_VERSION.txt`, por exemplo), ou o
histórico de runs do GitHub Actions já servem:

```
v1 (produção atual):  abc123
v2 (novo deploy):     def456   ← problema identificado após o deploy

Rollback: trocar a imagem de volta para abc123 (ver passo a passo acima).
```

### Rollback e banco

**Rollback de container NÃO significa automaticamente rollback de banco.** Se o deploy `v2`
rodou uma migration que `v1` não entende (ex.: uma coluna que `v1` nunca esperou receber
`NOT NULL`), simplesmente voltar o container para `v1` pode deixar a aplicação quebrada contra
o schema novo — o container voltou, o banco não.

Por isso, prefira migrations **backward-compatible** — a versão anterior do código continua
funcionando contra o schema novo — seguindo o padrão **EXPAND → DEPLOY → CONTRACT**:

```
1. EXPAND   — adicionar o novo (coluna/tabela) SEM remover o antigo.
              Migration só aditiva; v1 e v2 do código funcionam contra esse schema.
2. DEPLOY   — publicar o código (v2) que já usa o novo campo.
              Se algo der errado, rollback de container para v1 continua seguro.
3. CONTRACT — só depois de v2 estar estável em produção, remover o campo antigo
              (migration separada, deploy separado).
```

Evite fazer uma migration destrutiva (`DROP COLUMN`, renomear coluna, mudar tipo de forma
incompatível) no **mesmo** deploy que introduz o código que depende dela — isso é exatamente o
cenário em que rollback de container deixa de ser suficiente. Ver
[`DATABASE-STANDARD.md#migrations-destrutivas`](./DATABASE-STANDARD.md#migrations-destrutivas).

## Ambientes

Ver [`ARCHITECTURE-STANDARD.md#ambientes-dev--hml--prod`](./ARCHITECTURE-STANDARD.md#ambientes-dev--hml--prod).
Nenhum projeto é obrigado a ter homologação desde o primeiro dia, mas a arquitetura (variáveis
de ambiente, bancos separados por ambiente) nunca impede adicionar HML depois.

## Servidor (TrueNAS) e acesso externo (Cloudflare)

Cloudflare e TrueNAS são **infraestrutura**, tratados fora do código da aplicação:

- [`docs/deploy/TRUENAS.md`](./docs/deploy/TRUENAS.md) — implantação conceitual no TrueNAS.
- [`docs/deploy/TRUENAS-CLOUDFLARE.md`](./docs/deploy/TRUENAS-CLOUDFLARE.md) — HTTPS público via Cloudflare Tunnel.

A aplicação deve funcionar de forma idêntica com qualquer reverse proxy na frente (Cloudflare,
Nginx, Traefik, load balancer) ou até sem nenhum (acesso direto por IP:porta em dev) — porque
ela nunca lida com TLS/domínio, só escuta HTTP numa porta interna.

## Migração para outro servidor/nuvem

Ver [`MIGRATION-STANDARD.md`](./MIGRATION-STANDARD.md). Trocar de TrueNAS para VPS, AWS, Azure,
Google Cloud ou DigitalOcean é, por design, uma mudança de **onde** o Docker roda — não uma
reescrita da aplicação.
