# SECURITY-STANDARD.md

## Obrigatório em todo projeto

- Secrets **somente** em variáveis de ambiente / secret manager — nunca no Git.
- Validação de entrada em toda fronteira (API, Server Actions, forms) — usando os schemas Zod de `packages/shared`.
- Autenticação real (ver [`AUTH-STANDARD.md`](./AUTH-STANDARD.md)).
- Autorização **sempre verificada no backend**, nunca só escondida no frontend.
- CORS restrito a origens conhecidas (`CORS_ORIGIN`) — `*` é aceitável só em desenvolvimento local.
- Rate limiting nas rotas públicas da API (já vem configurado em `templates/api`).
- HTTPS em produção (via Cloudflare Tunnel, reverse proxy ou load balancer — nunca a aplicação lidando com TLS sozinha).
- Headers de segurança (`@fastify/helmet` na API; Next.js já aplica um baseline razoável).
- Menor privilégio: containers rodam com usuário não-root; credenciais de banco só com o acesso que a aplicação realmente precisa.
- Banco de dados **nunca** exposto à internet (sem `ports:` público no `docker-compose.yml`).
- Redis (quando existir) **nunca** exposto à internet.
- Interface administrativa do TrueNAS **nunca** exposta à internet.
- SMB **nunca** exposto à internet.
- SSH **nunca** exposto diretamente à internet — use VPN/Tunnel/bastion quando precisar de acesso remoto.
- Logs nunca contêm credenciais (lista completa abaixo).
- Dependências atualizadas — revise `pnpm audit`/Dependabot periodicamente.
- Separação real entre DEV / HML / PROD: bancos diferentes, secrets diferentes, nunca compartilhados.
- Backup existe e foi restaurado com sucesso ao menos uma vez (ver [`BACKUP-STANDARD.md`](./BACKUP-STANDARD.md)).
- Proteção contra upload malicioso sempre que houver upload de arquivo: validar tipo/tamanho, nunca executar o que foi enviado, servir a partir de um storage isolado.

## Nunca logar

```
Authorization
Cookie completo
password
token
refresh token
service key / service_role key
```

Se um log precisar indicar "o usuário estava autenticado", logue o `user.id`, nunca o token.

## Variáveis públicas (`NEXT_PUBLIC_` / `EXPO_PUBLIC_`)

Tudo que começa com `NEXT_PUBLIC_` (Next.js) ou `EXPO_PUBLIC_` (Expo) vai parar no bundle do
browser/app — ou seja, é público por definição, mesmo que "ninguém vá abrir o DevTools".
**Nunca** use esses prefixos para:

```
password, secret, service_role, token, DATABASE_URL, private_key
```

`scripts/validate-standard.ps1` falha (`FAIL`) se encontrar uma variável `NEXT_PUBLIC_*`/
`EXPO_PUBLIC_*` cujo nome sugere um desses casos.

## CORS

```ts
// apps/api/src/env.ts — já validado via Zod
CORS_ORIGIN=https://{{DOMAIN_WEB}},https://hml.{{DOMAIN_WEB}}
```

`*` (qualquer origem) só é aceitável em `NODE_ENV=development`. Nunca em produção.

## Banco, Redis e serviços internos

Regra simples: se um serviço não precisa ser acessado de fora do host, ele **não tem** `ports:`
publicado no `docker-compose.yml` — só participa da rede interna (`{{PROJECT_SLUG}}-network`) e
é acessado pelos outros containers pelo nome do serviço (`db`, `redis`, etc.), nunca por IP.

O mesmo princípio se aplica à **API**: quando o único consumidor é o `web` do mesmo compose
(sem Mobile, sem integração externa), a API também não publica porta no host — fica em
`expose:`, alcançável só pela rede Docker interna. `-PublicApi` (automático quando há Mobile)
é a exceção deliberada, documentada. Ver
[`DEPLOY-STANDARD.md#portas-e-exposição-da-api`](./DEPLOY-STANDARD.md#portas-e-exposição-da-api).

## Rate limiting

Já configurado por padrão em `templates/api` via `@fastify/rate-limit` (`RATE_LIMIT_MAX`,
`RATE_LIMIT_WINDOW`). Ajuste os valores por rota quando uma rota específica precisar de um
limite diferente (ex.: login mais restrito que leitura pública).

## Upload de arquivos

Ver [`BACKUP-STANDARD.md`](./BACKUP-STANDARD.md#storage) e a seção de storage do
`docker-compose.yml` gerado (`-Storage`). Ao aceitar upload:

- valide o tipo real do arquivo (não confie só na extensão/`Content-Type` enviado pelo cliente);
- limite o tamanho máximo;
- nunca sirva o arquivo enviado a partir de um caminho executável pelo servidor web;
- gere um nome novo para o arquivo salvo (não reutilize o nome enviado pelo cliente).

## Dependências

Sem processo pesado obrigatório — no mínimo, revise alertas do GitHub (Dependabot) e rode
`pnpm audit` antes de releases importantes. Atualize dependências com vulnerabilidade
conhecida com prioridade, mesmo fora do ciclo normal de manutenção.

## Ver também

- [`AUTH-STANDARD.md`](./AUTH-STANDARD.md)
- [`BACKUP-STANDARD.md`](./BACKUP-STANDARD.md)
- [`DEPLOY-STANDARD.md`](./DEPLOY-STANDARD.md)
- [`docs/deploy/TRUENAS-CLOUDFLARE.md`](./docs/deploy/TRUENAS-CLOUDFLARE.md) — como o HTTPS chega até a aplicação sem a aplicação precisar saber disso.
