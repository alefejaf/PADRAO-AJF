# DATABASE-STANDARD.md

## Padrão

**PostgreSQL** é o banco padrão para projetos próprios. **Drizzle ORM** é o padrão de schema e
migrations (ver `templates/database`). **Supabase** continua suportado como alternativa (ver
seção [Supabase](#supabase)) — não é obrigatório.

## Regra central

Todo schema é código. Toda alteração estrutural gera migration. **Nunca alterar o banco de
produção manualmente** (sem migration, sem histórico, sem rollback possível).

```
Código (src/schema/*.ts)
  ↓
Migration (drizzle-kit generate)
  ↓
Git (commit do schema + da migration juntos)
  ↓
Deploy
  ↓
Banco (drizzle-kit / script de migrate)
```

## Fluxo de alteração

```bash
# 1. edite packages/database/src/schema/*.ts
# 2. gere a migration
pnpm --filter @{{PROJECT_SLUG}}/database run generate
# 3. revise o SQL gerado em packages/database/migrations/
# 4. commit schema + migration juntos
# 5. aplique no banco alvo
pnpm --filter @{{PROJECT_SLUG}}/database run migrate
```

`pnpm run migrate` **nunca** roda automaticamente no boot da aplicação — é sempre um passo
explícito do processo de deploy (manual ou um step dedicado do CI/CD), para que quem faz o
deploy saiba exatamente quando o schema do banco está mudando.

## Migrations destrutivas

Mudanças como:

- `DROP TABLE`
- `DROP COLUMN`
- mudança de tipo incompatível
- remoção de constraint usada por dados existentes

**exigem análise manual** antes de aplicar em produção: confirme que nada depende mais da
coluna/tabela, faça backup antes de rodar, e prefira uma migration em duas etapas (deprecar →
remover num deploy seguinte) quando o dado for importante.

## Nunca

- Alterar o schema direto no banco de produção via `psql`/GUI sem gerar migration depois.
- Editar uma migration já aplicada em algum ambiente — crie uma nova migration corrigindo o que for necessário.
- Rodar `migrate` automaticamente num hook de boot do container.
- Expor a porta do PostgreSQL publicamente (ver [`SECURITY-STANDARD.md`](./SECURITY-STANDARD.md)).
- Usar senha padrão/fixa para o Postgres. `docker-compose.yml` nunca traz uma senha embutida —
  `POSTGRES_PASSWORD` é obrigatória via `.env` (`${POSTGRES_PASSWORD:?...}`); sem ela, o compose
  falha com uma mensagem clara em vez de subir com uma senha fraca conhecida.

## Web sem API separada

Quando o projeto tem `-Web -Database postgresql` mas **não** tem `-Api`, `packages/database` é
instalado como dependência do próprio `apps/web` (não da API, que não existe nesse cenário).
Server Actions e Route Handlers importam direto:

```ts
import { db, users } from "@{{PROJECT_SLUG}}/database";
```

Isso preserva a regra central deste documento (schema em código, migration por mudança
estrutural) mesmo sem uma API HTTP separada — só muda quem chama `packages/database`.

## Embedded x External

`-DatabaseMode` (gerador) decide de onde vem o PostgreSQL:

- **`embedded`** (padrão) — o `docker-compose.yml` sobe seu próprio serviço `db`
  (`postgres:16-alpine`), com volume persistente e `DATABASE_URL` montada a partir de
  `POSTGRES_USER`/`POSTGRES_PASSWORD`/`POSTGRES_DB` (definidas no `.env` da raiz).
- **`external`** — nenhum serviço `db` é criado. O projeto se conecta a um PostgreSQL que já
  existe (compartilhado, gerenciado por outra equipe, numa VPS separada, etc.) inteiramente via
  `DATABASE_URL` (obrigatória, sem valor padrão).

Nos dois casos, `packages/database` (schema, migrations, `pnpm run db:*`) funciona exatamente
igual — a diferença é só se o compose deste projeto também é responsável por rodar o banco.

## Supabase

Quando o projeto usa Supabase em vez de PostgreSQL "cru":

- Configure a conexão inteiramente via variável de ambiente (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`).
- **Nunca** coloque `SUPABASE_SERVICE_ROLE_KEY` em código que roda no browser/frontend — ela ignora Row Level Security.
- Separe explicitamente o client de browser (usa `SUPABASE_ANON_KEY`, respeita RLS) do client de servidor (pode usar a service role quando necessário, sempre em código server-only).
- Documente migrations do schema Supabase da mesma forma que uma migration Drizzle: mudança de schema é código versionado, não um clique na UI sem registro.
- Documente separadamente como Auth e Storage do Supabase estão configurados no projeto (ver [`AUTH-STANDARD.md`](./AUTH-STANDARD.md)).
- Sempre habilite e revise as políticas de **Row Level Security (RLS)** nas tabelas — não confie apenas na chave anônima estar "menos privilegiada".

Supabase nunca é obrigatório — é uma opção equivalente ao PostgreSQL + Drizzle para projetos
que preferem um backend gerenciado.

## Ver também

- [`templates/database/README.md`](./templates/database/README.md) — como o módulo funciona na prática.
- [`BACKUP-STANDARD.md`](./BACKUP-STANDARD.md) — backup e restore do banco.
- [`MIGRATION-STANDARD.md`](./MIGRATION-STANDARD.md) — migrar o banco para outro servidor.
- [`DEPLOY-STANDARD.md#rollback-e-banco`](./DEPLOY-STANDARD.md#rollback-e-banco) — por que rollback de container não é rollback de banco, e a estratégia EXPAND → DEPLOY → CONTRACT.
