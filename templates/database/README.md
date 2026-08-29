# @{{PROJECT_SLUG}}/database

Schema, client e migrations do PostgreSQL usando [Drizzle ORM](https://orm.drizzle.team).

## Estrutura

```
database/
├── src/
│   ├── schema/    # definição das tabelas (fonte da verdade)
│   ├── client.ts  # conexão/pool + instância drizzle
│   ├── migrate.ts # aplica migrations pendentes
│   └── index.ts
├── migrations/    # SQL gerado pelo drizzle-kit (versionado no Git)
└── drizzle.config.ts
```

## Fluxo de alteração de schema

```
editar src/schema/*.ts
  ↓
pnpm run generate   (gera SQL em migrations/)
  ↓
revisar o SQL gerado
  ↓
commit (schema + migration juntos)
  ↓
pnpm run migrate    (aplica no banco alvo)
```

## Scripts

| Script | Descrição |
|---|---|
| `pnpm run generate` | Gera uma nova migration a partir das mudanças em `src/schema`. |
| `pnpm run migrate` | Aplica migrations pendentes no banco definido em `DATABASE_URL`. |
| `pnpm run check` | Verifica se o schema em código está consistente com as migrations geradas. |
| `pnpm run studio` | Abre o Drizzle Studio para inspecionar o banco. |

## Regras importantes

- Toda alteração estrutural gera migration. Nunca alterar o banco de produção manualmente.
- Migrations destrutivas (`DROP TABLE`, `DROP COLUMN`, mudanças incompatíveis) exigem análise
  manual antes de aplicar em produção — ver [`DATABASE-STANDARD.md`](../../DATABASE-STANDARD.md).
- `pnpm run migrate` nunca é executado automaticamente no boot da aplicação; é um passo
  explícito do processo de deploy.
