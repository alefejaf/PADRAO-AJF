# V3-REPORT.md

Relatório da **Revisão V3** do PADRAO-AJF — ajustes e correções sobre a estrutura já existente
(V1/V2). Nada foi recriado do zero; nenhuma pasta fora de `PADRAO-AJF/` foi tocada.

## 1. Problemas identificados (auditoria antes de alterar)

Lendo `PROJECT-STANDARD.md`, `ARCHITECTURE-STANDARD.md`, `DEPLOY-STANDARD.md`,
`SECURITY-STANDARD.md`, `DATABASE-STANDARD.md`, `TESTING-STANDARD.md`, `README.md`,
`scripts/create-project.ps1`, `scripts/validate-standard.ps1`, os templates e os workflows,
foram confirmados os seguintes gaps reais (todos os 26 pontos pedidos na revisão eram
aplicáveis — nenhum já estava resolvido):

1. `-Mobile` sem `-Api` gerava um projeto arquiteturalmente incorreto (Mobile "acessando"
   um banco que não existe do jeito certo) sem nenhum aviso ou bloqueio.
2. `-Web -Database postgresql` sem `-Api` **não** ligava `packages/database` a `apps/web` —
   o banco ficava inacessível nesse cenário, apesar de ser um cenário explicitamente suportado.
3. `docker-compose.yml` tinha `POSTGRES_PASSWORD: changeme` fixo — uma senha padrão conhecida
   versionada no template.
4. `env_file: ./apps/api/.env` (e `./apps/web/.env.local`) no compose apontava para arquivos
   que **não existem** logo após gerar o projeto — `docker compose config` falhava
   imediatamente com "arquivo não encontrado", sem nenhuma orientação.
5. `depends_on` usava a forma antiga (lista de nomes), sem `condition: service_healthy` — nada
   garantia ordem de subida real após um restart do host.
6. Storage (`-Storage`) só considerava a API como dona do volume — num projeto Web-sem-API com
   Storage, o volume simplesmente não era montado em lugar nenhum.
7. Não existia noção de PostgreSQL "embedded x external" — todo projeto com `-Database
   postgresql` ganhava um container de banco, mesmo quando o banco já existia em outro lugar.
8. Portas eram sempre fixas (`3000`/`3001`) — dois projetos PADRAO-AJF no mesmo TrueNAS
   colidiriam certamente.
9. A API sempre publicava porta no host, mesmo quando só o Web (no mesmo compose) a consumia.
10. `container_name:` fixo nos três serviços — obstáculo real para rodar a mesma stack duas
    vezes no mesmo host (ex.: um ambiente de teste ao lado do de produção).
11. Rollback documentava tags, mas não como rastrear "qual tag está em produção agora", nem o
    caso em que rollback de container não é suficiente por causa de uma migration.
12. `validate-standard.ps1` cobria 6 checagens; a revisão pediu mais 14 categorias novas
    (placeholder esquecido, senha/URL hardcoded no compose, portas duplicadas, `NEXT_PUBLIC_*`
    com nome de segredo, JSON/YAML inválido, Dockerfile como root, schema ausente, etc).
13. Nenhuma checagem existia para placeholders `{{...}}` esquecidos num projeto gerado.
14. Nenhuma validação usava ferramentas externas (`docker compose config`, parse de JSON).
15. `validate-standard.ps1` não rodava em nenhum workflow — um projeto podia publicar imagem
    no GHCR mesmo com `.env` versionado por engano.
16. Não existia teste automatizado das combinações do gerador.
17. (consequência do 16) Nenhum cenário tinha build/Docker executado de forma repetível.
18. O `.env.example` do mobile já alertava sobre produção, mas sem menção explícita a nunca
    usar o hostname interno do Docker.
19. `NEXT_PUBLIC_API_URL` era a única variável de API do Web — usada tanto para chamadas do
    servidor quanto (implicitamente) do browser, sem separar os dois contextos.
20. Nenhuma checagem impedia uma variável `NEXT_PUBLIC_*`/`EXPO_PUBLIC_*` com nome de segredo.
21. Migrations/scripts já existiam corretamente (`db:generate`/`db:migrate`/`db:check`/
    `db:studio`) — nada a corrigir aqui além de reforçar a documentação de deploy.
22. Nada documentava que rollback de container ≠ rollback de banco, nem a estratégia
    EXPAND → DEPLOY → CONTRACT.
23. Healthcheck já estava correto e simples — preservado sem mudanças.
24. Nenhuma regra de segurança existente foi enfraquecida (auditado item a item).
25. Cloudflare já estava corretamente desacoplado — preservado, com uma nota nova esclarecendo
    que `-PublicApi` e alcançabilidade via Cloudflare Tunnel são coisas independentes.
26. Nenhuma dependência nova de infraestrutura (Kubernetes, Redis, etc.) foi adicionada.

## 2. Arquivos modificados

**Gerador e validador:**
- `scripts/create-project.ps1` — novos parâmetros (`-DatabaseMode`, `-WebPort`, `-ApiPort`,
  `-PublicApi`), regra Mobile→API, wiring de `packages/database` para Web sem API (package.json
  **e** `.env.example` **e** `docker-compose.yml`), geração de compose reescrita por completo
  (sem `container_name`/`env_file`, com `${VAR:-padrão}`/`${VAR:?obrigatório}`, `expose` x
  `ports`, storage no serviço certo, `depends_on` com `condition: service_healthy`), README e
  `.env.example` gerados atualizados, cópia de `scripts/validate-standard.ps1` para o projeto
  gerado.
- `scripts/validate-standard.ps1` — 14 checagens novas (seção 12 abaixo), correção de um bug
  real (`docker compose config` com stderr redirecionado virava erro terminante sob
  `$ErrorActionPreference = 'Stop'`).
- `scripts/test-generator.ps1` — **novo**. Gera e valida os 8 cenários de referência; usa
  `$ErrorActionPreference = 'Continue'` de propósito (ver seção 3 — evita que a saída em
  stderr do `docker build`/BuildKit derrube o script).

**Workflows:**
- `infra-template/github-workflows/ci.yml` — roda `validate-standard.ps1` primeiro.
- `infra-template/github-workflows/docker-publish.yml` — roda `validate-standard.ps1` em cada
  job antes de buildar/publicar.

**Templates:**
- `templates/web/src/lib/env.ts` — nova variável `API_INTERNAL_URL`.
- `templates/web/src/lib/api-url.ts` — **novo** helper `getServerApiBaseUrl()`.
- `templates/web/src/lib/api-url.test.ts` — **novo** teste.
- `templates/web/src/app/status/page.tsx` — usa `getServerApiBaseUrl()` em vez de ler
  `NEXT_PUBLIC_API_URL` direto no servidor.
- `templates/web/.env.example` — documenta `API_INTERNAL_URL`.
- `templates/web/README.md` — seção nova sobre client-side x server-side, e uso de
  `packages/database` sem API.
- `templates/mobile/.env.example`, `templates/mobile/README.md` — reforço explícito contra
  `localhost`/hostname interno do Docker em produção.

**Documentação (raiz):**
- `PROJECT-STANDARD.md` — nova regra 20 (Mobile exige API); renumeração 20→26.
- `ARCHITECTURE-STANDARD.md` — regra Mobile→API, Web-sem-API usa `packages/database`, seções
  novas "Banco embedded x external" e "Portas e exposição da API".
- `DATABASE-STANDARD.md` — seções novas "Web sem API separada" e "Embedded x External"; nunca
  usar senha padrão.
- `DEPLOY-STANDARD.md` — seções novas "Variáveis de ambiente: raiz x por app", "Portas e
  exposição da API", "Client-side x server-side", "Rastreando a versão em produção",
  "Rollback e banco" (EXPAND/DEPLOY/CONTRACT); fluxo do CI atualizado com validate-standard.
- `SECURITY-STANDARD.md` — princípio "API interna por padrão" e seção sobre variáveis públicas
  com nome de segredo.
- `NAMING-STANDARD.md` — decisão de não usar `container_name`; seção nova de portas.
- `BACKUP-STANDARD.md` — nota sobre embedded x external e sobre qual serviço monta o storage.
- `CHECKLIST-PRODUCAO.md` — itens novos (validate-standard, `.env` da raiz, portas, PublicApi,
  placeholders, rollback de banco).
- `TESTING-STANDARD.md` — seção nova sobre `test-generator.ps1` e validate-standard no CI.
- `docs/deploy/TRUENAS-CLOUDFLARE.md` — nota sobre `-PublicApi` ser independente de
  alcançabilidade via Cloudflare Tunnel.
- `README.md` (raiz) — exemplos novos, `test-generator.ps1`, descrição atualizada do validador.
- `.gitignore` — **novo** na raiz do PADRAO-AJF (gap encontrado ao rodar o próprio validador
  contra o PADRAO-AJF).

## 3. Correções aplicadas

Ver seção 1 (cada problema tem a correção correspondente descrita ali) e seção 2 (onde). Duas
correções vieram só de **testar de verdade** o que foi implementado, não da leitura da
especificação:

- **Bug real do validador**: `docker compose config 2>&1` sob `$ErrorActionPreference = 'Stop'`
  transformava a saída de erro do Docker num erro PowerShell terminante, derrubando o script
  inteiro em vez de virar um `WARN`. Corrigido relaxando `$ErrorActionPreference` só ao redor
  dessa chamada.
- **Gap real no cenário Web+Postgres sem API**: a dependência de workspace
  (`@slug/database` no `package.json`) estava correta, mas `DATABASE_URL` nunca chegava ao
  container do Web em `docker-compose.yml` nem ao `.env.example` do Web — o banco estava
  "conectado" só no papel. Corrigido generalizando a construção de `DATABASE_URL` para o
  serviço que efetivamente precisa dela (API quando existe, senão Web). Também faltava
  `depends_on: db (service_healthy)` no Web nesse mesmo cenário — corrigido junto.
- **Regeneração (`-Force`) extremamente lenta**: `Expand-TokensInTree` percorria a árvore
  inteira do projeto de destino, incluindo `node_modules` já instalado — em um projeto já
  buildado isso significa dezenas de milhares de arquivos irrelevantes. Descoberto ao
  regenerar um cenário já instalado durante os testes (ficou "pendurado" por minutos).
  Corrigido para nunca descer em `node_modules/.git/.next/.expo/.pnpm-store/dist/coverage` —
  regeneração do mesmo cenário caiu de "travado" para **1,4s**.
- **Mesmo bug do `docker compose config` (acima), só que em `test-generator.ps1`**: todo
  `docker build`/`docker compose config`/`pnpm run *` do script usa `2>&1` para capturar a
  saída, e o BuildKit do `docker build` sempre escreve o progresso em stderr — sob `'Stop'`,
  isso derrubava o script inteiro assim que `-DockerBuild` tentava a primeira imagem (achado
  ao testar o próprio `-DockerBuild`, exatamente o comando recomendado na seção 20 deste
  relatório). Corrigido trocando `$ErrorActionPreference` do script de `'Stop'` para
  `'Continue'` (o `throw` de `create-project.ps1` continua parando a execução normalmente,
  por ser um erro terminante explícito, independente dessa preferência). Reproduzido e
  confirmado corrigido rodando `-DockerBuild -Scenario cenario08-...` isoladamente.

## 4. Decisões técnicas

- **Mobile sem API**: modo interativo habilita a API automaticamente (com aviso, sem
  interromper a sessão); modo por argumentos para com erro (previsível para automação/CI). Ver
  `ARCHITECTURE-STANDARD.md`.
- **Env vars do compose via `${VAR:-padrão}` / `${VAR:?mensagem}`**, carregadas do `.env` da
  raiz — não `env_file:` por app. `docker compose config` funciona sem nenhum `.env` real
  existir ainda; só o genuinamente obrigatório (senha/URL do banco) força um erro claro.
- **`container_name` removido** — o nome do projeto compose já nomeia os containers de forma
  previsível; serviços continuam endereçados por nome (`docker compose exec api`).
- **Porta interna sempre fixa, só o mapeamento pro host é configurável** — evita ter que tocar
  em Dockerfile/healthcheck/código por causa de uma escolha de porta.
- **`expose` em vez de `ports` para a API quando `-PublicApi` está desligado** — reduz
  superfície de exposição por padrão; Mobile força `-PublicApi` (é sempre um consumidor de fora
  da rede Docker do compose).
- **`docker compose config` com `FAIL` vira `WARN`** no validador (não `FAIL`) — um projeto
  recém-gerado sem `.env` ainda é, por design, um estado válido (ver ponto 4 da revisão); o que
  importa é a mensagem ser clara quando isso acontece.
- **Placeholder `{{...}}` só é `FAIL` fora de `templates/`/`infra-template/` e fora da raiz do
  próprio PADRAO-AJF** — o validador detecta automaticamente se está validando a fonte (tem
  `templates/` + `scripts/create-project.ps1`) ou um projeto gerado.
- **`API_INTERNAL_URL` + `NEXT_PUBLIC_API_URL`** — dois nomes, dois contextos, para nunca gerar
  uma configuração que funciona no servidor e quebra no browser (ou vice-versa).

## 5. Testes realizados

Executado de verdade nesta sessão, não só planejado:

1. **`scripts/test-generator.ps1 -Full`** nos 8 cenários de referência: geração,
   `validate-standard.ps1`, `pnpm install`, `lint`, `typecheck`, `test`, `build`, `docker
   compose config`.
2. **`scripts/validate-standard.ps1`** rodado individualmente nos 8 cenários após a correção
   de performance (seção 3) e da regeneração do cenário 2 — números finais na seção 7.
3. **Docker build real** (não só `docker compose config`) de `apps/web` e `apps/api` do
   cenário 4 (Web+API+Postgres embedded) — as duas imagens buildaram sem erro.
4. **`docker compose up`/`down` real** do cenário 4: os 3 containers (`db`, `api`, `web`)
   subiram na ordem certa (`db` → healthy → `api` → healthy → `web`), nomeados
   automaticamente pelo compose (`cenario04-...-db-1`, `-api-1`, `-web-1` — sem
   `container_name`), com `db`/`api` **sem** porta publicada no host (`PublicApi=false`) e
   `web` publicado em `3000`. `GET /api/health` (host) e `GET /status` responderam OK, e
   `/status` mostrou o healthcheck da API **também OK** — prova de que `API_INTERNAL_URL`
   resolveu corretamente `http://api:3001` dentro da rede Docker.
5. **`docker compose up`/`down` real** do cenário 6 (Web+API+Mobile+Postgres,
   `PublicApi=true` automático por causa do Mobile): confirmado que a API fica publicada no
   host (`0.0.0.0:3001->3001/tcp`) e responde direto (`curl http://localhost:3001/health`) —
   ao contrário do cenário 4, onde a mesma porta não responde do host.
6. Confirmado que `-Mobile` sem `-Api` para com erro claro no modo por argumentos, e que não
   sobra nenhum diretório parcial no disco quando isso acontece.
7. **`scripts/test-generator.ps1 -DockerBuild`** (o comando recomendado na seção 20) rodado
   isoladamente após a correção do bug de `$ErrorActionPreference` (seção 3) — `Generated`,
   `Validate`, `PnpmInstall`, `Lint`, `Typecheck`, `Test`, `Build`, `ComposeConfig` e
   `DockerBuild` todos `PASS`.

Todos os containers/imagens/volumes de teste foram removidos ao final (nenhum artefato de
teste ficou no Docker local nem fora de `PADRAO-AJF/`).

## 6. Cenários do gerador testados

Via `scripts/test-generator.ps1` (8 cenários de referência pedidos na revisão):

| # | Cenário | Flags |
|---|---|---|
| 1 | Web somente | `-Web -Database none` |
| 2 | Web + PostgreSQL embedded | `-Web -Database postgresql -DatabaseMode embedded` |
| 3 | Web + PostgreSQL external | `-Web -Database postgresql -DatabaseMode external` |
| 4 | Web + API + PostgreSQL embedded | `-Web -Api -Database postgresql -DatabaseMode embedded` |
| 5 | Web + API + Supabase | `-Web -Api -Database supabase` |
| 6 | Web + API + Mobile + PostgreSQL | `-Web -Api -Mobile -Database postgresql` |
| 7 | Web + PWA | `-Web -Pwa -Database none` |
| 8 | API somente + PostgreSQL | `-Api -Database postgresql` |

## 7. Cenários que passaram

Todos os 8/8. `pnpm install`, `lint`, `typecheck` e `test` **PASS** em todos; `validate-standard.ps1`
com **0 FAIL** em todos:

| # | Cenário | validate-standard |
|---|---|---|
| 1 | Web somente | 24 PASS, 2 WARN, 0 FAIL |
| 2 | Web + PostgreSQL embedded | 25 PASS, 2 WARN, 0 FAIL |
| 3 | Web + PostgreSQL external | 25 PASS, 2 WARN, 0 FAIL |
| 4 | Web + API + PostgreSQL embedded | 28 PASS, 3 WARN, 0 FAIL |
| 5 | Web + API + Supabase | 27 PASS, 3 WARN, 0 FAIL |
| 6 | Web + API + Mobile + PostgreSQL | 28 PASS, 3 WARN, 0 FAIL |
| 7 | Web + PWA | 24 PASS, 2 WARN, 0 FAIL |
| 8 | API somente + PostgreSQL | 24 PASS, 3 WARN, 0 FAIL |

**Total: 205 PASS, 20 WARN, 0 FAIL** em 8 cenários.

## 8. Warnings

Todos os WARNs encontrados são esperados/documentados, não indicam defeito:

- **`env-not-committed`** (8/8 cenários) — o `.env` criado propositalmente para testar
  `docker compose config` existe localmente; o validador sempre avisa para conferir o
  `.gitignore` quando um `.env` real existe (comportamento por design).
- **`image-not-only-latest`** (8/8) — `docker-compose.yml` referencia a imagem só por
  `:latest`; informativo (normal para build local — produção deve fixar por SHA, o que o
  `docker-publish.yml` já faz).
- **`compose-no-localhost`** (cenários 4, 5, 6, 8 — os com API) — `CORS_ORIGIN`/
  `NEXT_PUBLIC_API_URL` usam `localhost` como valor padrão de conveniência local; esperado
  (documentado no próprio `docker-compose.yml` e em `DEPLOY-STANDARD.md`) — produção
  sobrescreve via `.env`.

## 9. Failures

**Nenhuma.** `validate-standard.ps1`: 0 FAIL em 8/8 cenários.

Uma categoria de falha apareceu nesta sessão e, na época, foi tratada como **não-defeito
documentado** (igual à V1/V2): `pnpm run build` falhava em `apps/web` (todos os cenários com
Web, exceto o cenário 8 que não tem Web) rodado direto no Windows sem Developer Mode
habilitado — `next build` com `output: "standalone"` tenta criar symlinks, e o Windows recusa
sem privilégio de symlink. Confirmado então que isso era 100% específico do host de
desenvolvimento Windows: o `docker build` do mesmo `apps/web`, rodando dentro do container
Linux, passava sem erro.

**Isso deixou de ser apenas "documentado" e passou a ser corrigido de verdade** — ver a seção
[Compatibilidade Windows + Next.js Standalone + pnpm](#compatibilidade-windows--nextjs-standalone--pnpm)
abaixo. `Build` agora é `PASS` em 8/8 cenários rodando `pnpm run build` direto neste mesmo
Windows, sem Developer Mode, sem admin.

## 9b. Correções pós-V3 (pedidas depois da entrega)

Duas correções pontuais, sobre o que já estava em produção pela V3:

1. **`test-generator.ps1` não falhava quando uma etapa falhava.** O código de saída só olhava
   as colunas `Generated`/`Validate` — um `FAIL` em `Lint`/`Typecheck`/`Test`/`Build`/
   `ComposeConfig`/`DockerBuild` aparecia na tabela mas o script mesmo assim reportava sucesso
   (`exit 0`). Corrigido: qualquer coluna da linha (exceto `Scenario`/`Notes`) igual a `'FAIL'`
   agora reprova aquele cenário. **Reproduzido antes da correção** (`-Full` num cenário Web,
   onde `Build` falha no Windows por causa do symlink já documentado — a tabela mostrava
   `Build: FAIL` e o script ainda assim dizia "sucesso") e **confirmado depois** (mesmo caso
   agora reporta `1 de 1 cenário(s) tiveram ao menos uma etapa com FAIL` e `exit 1`).
2. **Healthcheck do Postgres usava `-U postgres` fixo**, ignorando `POSTGRES_USER`/
   `POSTGRES_DB` configurados no `.env`. Corrigido para `pg_isready -U
   "${POSTGRES_USER:-postgres}" -d "${POSTGRES_DB:-<slug>}"` — mesma variável e mesmo valor
   padrão já usados no bloco `environment:` do serviço `db`.
   - **Regressão encontrada e corrigida durante a própria correção**: a primeira versão usou
     `$POSTGRES_USER`/`$POSTGRES_DB` sem o `${...:-default}`. Funciona quando essas variáveis
     estão no `.env`, mas o `docker compose` interpola `$VAR` em **qualquer** valor do
     arquivo (não só em `environment:`) — sem default, uma variável ausente do `.env` (o caso
     mais comum, que depende do fallback `postgres`/nome do projeto) virava string vazia:
     `pg_isready -U "" -d ""`, quebrando o healthcheck justamente no cenário padrão. Detectado
     rodando `docker compose config` antes de assumir que a correção estava certa.
   - Verificado com `docker compose up` real: `healthy` tanto sem nenhuma variável definida
     (usa os padrões) quanto com `POSTGRES_USER`/`POSTGRES_DB` customizados no `.env`.

## Compatibilidade Windows + Next.js Standalone + pnpm

### Causa

`output: "standalone"` do Next.js faz o build copiar as dependências de produção rastreadas
para `.next/standalone/node_modules` — e essa cópia é feita **via symlinks**, não cópia de
arquivo. Dentro do Dockerfile (sempre Linux) isso é transparente. Rodando `pnpm run build`
direto num Windows sem privilégio de symlink — que este padrão **nunca exige** (nada de
PowerShell como Administrador, nada de Developer Mode) — essa etapa específica falhava com:

```
EPERM: operation not permitted, symlink
```

mesmo com a compilação do Next.js em si (`Compiled successfully`) tendo funcionado
normalmente — o erro só aparecia depois, na etapa de "Collecting build traces" / cópia para
`.next/standalone`. Isso explica os 7 `FAIL` de `Build` da V3 (todo cenário com `apps/web`,
exceto o único sem Web).

### Solução adotada

`output: "standalone"` passou a ser **condicional** a uma variável de ambiente,
`NEXT_OUTPUT_STANDALONE`, que só o `Dockerfile` da própria imagem Web define — nunca o build
local:

**`templates/web/next.config.mjs` — antes:**

```js
const nextConfig = {
  output: "standalone",
  outputFileTracingRoot: path.join(__dirname, "../../"),
  // ...
};
```

**`templates/web/next.config.mjs` — depois:**

```js
const isStandalone = process.env.NEXT_OUTPUT_STANDALONE === "true";

const nextConfig = {
  ...(isStandalone ? { output: "standalone" } : {}),
  outputFileTracingRoot: path.join(__dirname, "../../"),
  // ...
};
```

**`templates/web/Dockerfile` (estágio de build) — antes:**

```dockerfile
ENV NEXT_TELEMETRY_DISABLED=1
RUN pnpm --filter {{PROJECT_SLUG}}-web run build
```

**`templates/web/Dockerfile` (estágio de build) — depois:**

```dockerfile
ENV NEXT_TELEMETRY_DISABLED=1
ENV NEXT_OUTPUT_STANDALONE=true
RUN pnpm --filter {{PROJECT_SLUG}}-web run build
```

O estágio final (`runtime`) do Dockerfile **não mudou** — continua copiando exatamente
`.next/standalone`, `.next/static` e `public` do estágio de build; como o estágio de build
sempre define `NEXT_OUTPUT_STANDALONE=true` antes de buildar, esses caminhos sempre existem
dentro do Docker, igual a antes.

### Resultado

| | Comando | Output do Next.js | Symlink? |
|---|---|---|---|
| Local (Windows/Linux/Mac, `pnpm run build`, e o `build` do `ci.yml`) | `pnpm run build` | padrão (sem `standalone`) | Não — nunca precisa de privilégio especial |
| Docker (`docker build`, produção real) | mesmo `pnpm run build`, com `NEXT_OUTPUT_STANDALONE=true` do Dockerfile | `standalone` | Sim, mas sempre dentro do container Linux |

A imagem Docker de produção continua exatamente tão otimizada quanto antes — nada foi
removido, só passou a ser condicional a onde o build roda. `ci.yml` roda o build normal (sem
standalone) como gate de sanidade; quem valida o build de produção de verdade é o `docker
build` do `docker-publish.yml`, que roda em runner Linux e sempre passou por essa etapa sem
problema. Documentado em detalhe em
[`DEPLOY-STANDARD.md#build-local-x-build-de-produção`](./DEPLOY-STANDARD.md#build-local-x-build-de-produção)
e em `templates/web/README.md`.

### Verificação

- `pnpm run build` local (Windows, sem admin, sem Developer Mode): `next build` → `Compiled
  successfully` → sem etapa de standalone → **sem erro de symlink**.
- `.\scripts\test-generator.ps1 -Full`: **8/8 cenários com `Build: PASS`** (era 7/8 `FAIL`).
- `.\scripts\test-generator.ps1 -DockerBuild`: **8/8 cenários com todas as 9 colunas PASS**,
  incluindo `DockerBuild: PASS` — confirma que a imagem Docker continua buildando com
  `output: "standalone"` normalmente.
- Nenhuma outra parte do padrão foi alterada (API Fastify, banco, Drizzle, Supabase, Mobile,
  PWA, `create-project.ps1`, regras de segurança, CI/CD, portas, storage, `PublicApi`,
  `DatabaseMode` — todos intocados).

## 10. Pendências

- ~~`next build` local no Windows sem Developer Mode ligado esbarrava na limitação de symlink
  do `output: standalone`~~ — **corrigido** (ver
  [Compatibilidade Windows + Next.js Standalone + pnpm](#compatibilidade-windows--nextjs-standalone--pnpm)).
  `Build` é `PASS` em 8/8 cenários, incluindo neste mesmo host Windows, sem Developer Mode e
  sem admin.
- Testes de integração com Postgres real em CI continuam fora do escopo do gerador (por
  design — ver `TESTING-STANDARD.md`), como já era antes da V3.
- Publicação real no GHCR e deploy num TrueNAS físico não foram exercitados (exigiriam
  credenciais e servidor reais).

## 11. Como criar um projeto Web simples

```powershell
.\scripts\create-project.ps1 -Name "site-institucional" -Web -Database none
```

## 12. Como criar Web + PostgreSQL

```powershell
.\scripts\create-project.ps1 -Name "meu-projeto" -Web -Database postgresql
```

Sem `-Api`, o próprio Web (Server Actions/Route Handlers) fala com `packages/database`
diretamente — `DATABASE_URL` já chega ao container do Web em `docker-compose.yml`.

## 13. Como criar Web + API

```powershell
.\scripts\create-project.ps1 -Name "meu-projeto" -Web -Api -Database postgresql
```

## 14. Como criar Web + API + Mobile

```powershell
.\scripts\create-project.ps1 -Name "meu-projeto" -Web -Api -Mobile -Database postgresql
```

`-Api` é obrigatório com `-Mobile` — o script habilita sozinho no modo interativo, ou para com
erro no modo por argumentos se `-Api` não foi passado.

## 15. Como definir portas

```powershell
.\scripts\create-project.ps1 -Name "meu-projeto" -Web -Api -Database postgresql `
  -WebPort 3100 -ApiPort 3101
```

A porta interna do container nunca muda (`3000`/`3001`) — só o mapeamento para o host, para
não colidir com outro projeto PADRAO-AJF no mesmo servidor.

## 16. Como usar PostgreSQL embedded

```powershell
.\scripts\create-project.ps1 -Name "meu-projeto" -Web -Api -Database postgresql -DatabaseMode embedded
```

(É o padrão — `-DatabaseMode embedded` pode ser omitido.) O compose sobe seu próprio container
`db`; defina `POSTGRES_PASSWORD` no `.env` da raiz antes de `docker compose up`.

## 17. Como usar banco external

```powershell
.\scripts\create-project.ps1 -Name "meu-projeto" -Web -Api -Database postgresql -DatabaseMode external
```

Nenhum container de banco é criado; defina `DATABASE_URL` (apontando para o Postgres que já
existe) no `.env` da raiz antes de `docker compose up`.

## 18. Como executar validate-standard

```powershell
.\scripts\validate-standard.ps1                    # projeto atual
.\scripts\validate-standard.ps1 -Path ..\gestao-frota
```

Já roda automaticamente em `ci.yml` e `docker-publish.yml` de todo projeto gerado.

## 19. Como executar test-generator

```powershell
.\scripts\test-generator.ps1                # estrutural, os 8 cenários (rápido)
.\scripts\test-generator.ps1 -Full          # + pnpm install/lint/typecheck/test/build/compose config
.\scripts\test-generator.ps1 -DockerBuild   # + docker build de cada imagem
.\scripts\test-generator.ps1 -Scenario cenario04-web-api-postgres-embedded -Full
```

## 20. Recomendação para colocar o PADRAO-AJF em produção

1. Rode `.\scripts\test-generator.ps1 -DockerBuild` uma vez, localmente, antes de confiar no
   padrão para um projeto real — confirma que as 8 combinações de referência geram, instalam,
   buildam e sobem em Docker sem intervenção manual.
2. Gere o primeiro projeto real e rode `docker compose up` até o healthcheck ficar `healthy`
   antes de configurar CI/CD — valide o ciclo local primeiro.
3. Só depois conecte o GitHub Actions (GHCR) e o TrueNAS/Cloudflare Tunnel, seguindo
   `docs/deploy/TRUENAS.md` e `docs/deploy/TRUENAS-CLOUDFLARE.md`.
4. Trate `scripts/validate-standard.ps1` como um gate real, não decorativo — um `FAIL` no CI já
   bloqueia a publicação da imagem; não contorne isso com `--no-verify`-equivalentes.
5. Releia `PROJECT-STANDARD.md` (as 26 regras) antes de qualquer mudança de arquitetura futura,
   feita por humano ou por IA.
