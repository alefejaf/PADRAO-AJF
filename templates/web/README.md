# {{PROJECT_SLUG}}-web

Aplicação Web de {{PROJECT_NAME}}, construída com [Next.js](https://nextjs.org) (App Router) + TypeScript.

## Rotas

| Rota | Descrição |
|---|---|
| `/` | Página inicial, com exemplo de Server Action + validação Zod. |
| `/status` | Mostra o resultado de `/api/health` (e da API separada, se configurada). |
| `/api/health` | Healthcheck usado pelo Docker e pelo monitoramento. |

## Desenvolvimento

```bash
cp .env.example .env.local
pnpm install
pnpm --filter {{PROJECT_SLUG}}-web run dev
```

## Scripts

| Script | Descrição |
|---|---|
| `pnpm run dev` | Sobe a aplicação em modo desenvolvimento. |
| `pnpm run build` | Build (output padrão do Next.js — funciona em qualquer SO, sem privilégio de symlink). |
| `pnpm run start` | Sobe o build de produção. |
| `pnpm run lint` | Executa o ESLint (`eslint-config-next`). |
| `pnpm run test` | Executa os testes (Vitest). |

## Backend

### Com `apps/api`

Duas variáveis, dois contextos diferentes (ver `src/lib/api-url.ts` e `DEPLOY-STANDARD.md`):

| Variável | Usada por | Exemplo |
|---|---|---|
| `NEXT_PUBLIC_API_URL` | **Browser** (client-side) | `https://api-{{PROJECT_SLUG}}.exemplo.com.br` — precisa ser pública/HTTPS |
| `API_INTERNAL_URL` | **Servidor** (Server Actions/Route Handlers/Server Components) | `http://api:3001` — só resolve dentro da mesma rede Docker |

Nunca use `API_INTERNAL_URL` (nem qualquer hostname interno tipo `api:3001`) em código que
roda no browser — ele não existe fora do docker-compose. Código client-side sempre lê
`NEXT_PUBLIC_API_URL`.

### Sem `apps/api`

Quando o banco é PostgreSQL e não há API separada, `packages/database` já vem instalado como
dependência deste app — importe direto em Server Actions/Route Handlers:

```ts
import { db, users } from "@{{PROJECT_SLUG}}/database";
```

Ver [`DATABASE-STANDARD.md`](../../DATABASE-STANDARD.md) e `src/app/actions.ts` para o padrão de
Server Action + validação Zod já usado neste template.

## Docker

```bash
docker build -f apps/web/Dockerfile -t {{PROJECT_SLUG}}-web .
docker run --rm -p 3000:3000 --env-file .env.local {{PROJECT_SLUG}}-web
```

Só a imagem Docker usa o output `standalone` do Next.js (o Dockerfile define
`NEXT_OUTPUT_STANDALONE=true` antes de buildar) — `pnpm run build` local nunca precisa disso
nem de privilégio de symlink. Ver [`DEPLOY-STANDARD.md#build-local-x-build-de-produção`](../../DEPLOY-STANDARD.md#build-local-x-build-de-produção).
