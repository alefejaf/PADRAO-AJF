# {{PROJECT_SLUG}}-api

API HTTP de {{PROJECT_NAME}}, construída com [Fastify](https://fastify.dev) + TypeScript.

## Rotas

| Método | Rota | Descrição |
|---|---|---|
| GET | `/health` | Healthcheck usado pelo Docker e pelo monitoramento. |
| GET | `/version` | Versão e commit da imagem em execução. |
| GET | `/example?name=` | Rota de exemplo com validação via Zod (`@{{PROJECT_SLUG}}/shared`). |

## Desenvolvimento

```bash
cp .env.example .env
pnpm install
pnpm --filter {{PROJECT_SLUG}}-api run dev
```

## Scripts

| Script | Descrição |
|---|---|
| `pnpm run dev` | Sobe a API com reload automático. |
| `pnpm run build` | Verifica os tipos (não gera arquivos — a API roda TypeScript diretamente via `tsx`). |
| `pnpm run start` | Sobe a API em modo produção. |
| `pnpm run lint` | Executa o ESLint. |
| `pnpm run test` | Executa os testes (Vitest). |

## Segurança

- Headers de segurança via `@fastify/helmet`.
- CORS restrito por `CORS_ORIGIN` (nunca `*` em produção).
- Rate limiting global via `@fastify/rate-limit`.
- Erros nunca vazam stack trace ao cliente (ver `src/errors/error-handler.ts`).
- Shutdown gracioso em `SIGTERM`/`SIGINT` (fecha conexões antes de sair).

Ver [`SECURITY-STANDARD.md`](../../SECURITY-STANDARD.md) para a política completa.

## Docker

```bash
docker build -f apps/api/Dockerfile -t {{PROJECT_SLUG}}-api .
docker run --rm -p 3001:3001 --env-file .env {{PROJECT_SLUG}}-api
```
