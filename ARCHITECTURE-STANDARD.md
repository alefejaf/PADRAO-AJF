# ARCHITECTURE-STANDARD.md

## Princípio central

O PADRAO-AJF não é um conjunto de três templates enormes duplicando código. É uma estrutura
**modular**: `scripts/create-project.ps1` monta a estrutura necessária combinando os módulos de
`templates/` de acordo com o que o projeto realmente precisa.

```
templates/
├── web/       → apps/web        (só se -Web)
├── api/       → apps/api        (só se -Api)
├── mobile/    → apps/mobile     (só se -Mobile)
├── database/  → packages/database (só se -Database postgresql)
└── shared/    → packages/shared (sempre)
    └── api-client/ → packages/api-client (só se -Api e (-Web ou -Mobile))
```

Nenhum projeto gerado contém pastas que não usa.

## Stack padrão

| Camada | Tecnologia |
|---|---|
| Web | Next.js + TypeScript |
| App mobile | React Native (Expo) + TypeScript |
| API separada | Fastify + TypeScript |
| Banco | PostgreSQL |
| ORM / migrations | Drizzle ORM |
| Validação | Zod |
| Monorepo | pnpm workspaces |

**Sem Turborepo** por padrão — só entra se houver benefício claro e mensurável (build
distribuído, cache remoto) que o `pnpm -r` sozinho não resolve. Prioridade: simplicidade,
organização, portabilidade, manutenção — nessa ordem de importância diante de qualquer ganho
marginal de performance de build.

## Quando usar API separada

**API separada não é obrigatória em todo projeto.**

Projeto simples:

```
Next.js → PostgreSQL / Supabase
```

Usa Server Actions, Route Handlers ou o próprio backend do Next.js.

Projeto com necessidade real de API:

```
Web → API (Fastify) → PostgreSQL
```

Crie API separada quando existir **pelo menos uma** destas necessidades:

- aplicativo mobile consumindo o mesmo backend;
- múltiplos consumidores (web + mobile + integrações);
- integrações externas que precisam de um backend estável;
- regra de negócio compartilhada entre diferentes clientes.

Nunca crie API separada só porque "é o padrão" — isso é overengineering e o
`PROJECT-STANDARD.md` proíbe explicitamente.

## Fluxo de dados obrigatório

```
Mobile  → HTTPS → API → Banco
Web     → API (ou Server Actions/Route Handlers) → Banco
```

O app mobile **nunca** acessa PostgreSQL diretamente — por isso **Mobile exige API separada**.
`create-project.ps1` aplica isso na geração do projeto: no modo interativo, escolher Mobile sem
API habilita a API automaticamente (com aviso); no modo por argumentos, `-Mobile` sem `-Api`
para o script com um erro claro em vez de gerar um projeto architecturalmente incorreto.

Quando o banco é PostgreSQL e **não** há API separada, o próprio `apps/web` recebe
`packages/database` como dependência (Server Actions/Route Handlers falam com o banco
diretamente) — ver [`DATABASE-STANDARD.md`](./DATABASE-STANDARD.md).

## Banco embedded x external

`-DatabaseMode` (só relevante com `-Database postgresql`) decide se o `docker-compose.yml`
gerado sobe seu próprio PostgreSQL ou se conecta a um banco que já existe:

| Modo | Serviço `db` no compose | `DATABASE_URL` |
|---|---|---|
| `embedded` (padrão) | Sim | Montado a partir de `POSTGRES_USER`/`POSTGRES_PASSWORD`/`POSTGRES_DB` |
| `external` | Não | Obrigatória via variável de ambiente própria |

Ver [`DATABASE-STANDARD.md`](./DATABASE-STANDARD.md#embedded-x-external).

## Portas e exposição da API

`-WebPort`/`-ApiPort` controlam só a porta publicada no **host** — a porta interna do container
continua fixa (`3000`/`3001`), para evitar colisão quando há vários projetos PADRAO-AJF no mesmo
servidor. `-PublicApi` decide se a API é publicada no host (`ports:`) ou fica só na rede Docker
interna (`expose:`, alcançável apenas pelo `web` do mesmo compose) — necessário publicar quando
há Mobile ou qualquer consumidor fora do compose. Mobile força `-PublicApi` automaticamente.
Detalhes em [`DEPLOY-STANDARD.md`](./DEPLOY-STANDARD.md#portas-e-exposição-da-api).

## Formato de um projeto gerado

```
{{PROJECT_SLUG}}/
├── apps/
│   ├── web/            (se -Web)
│   ├── api/             (se -Api)
│   └── mobile/          (se -Mobile)
├── packages/
│   ├── shared/          (sempre)
│   ├── database/        (se banco = postgresql)
│   └── api-client/      (se -Api e há web ou mobile)
├── infra/
│   ├── docker/
│   └── scripts/
├── .github/workflows/
├── docker-compose.yml
├── pnpm-workspace.yaml
├── .env.example
├── .gitignore
├── package.json
└── README.md
```

## Ambientes (DEV / HML / PROD)

A arquitetura já suporta os três ambientes via variável de ambiente — sem forçar nenhum
projeto a ter homologação desde o dia 1:

| Ambiente | Web | Banco/secrets |
|---|---|---|
| DEV | `localhost` | banco local/dev, secrets de dev |
| HML | `hml.exemplo.com.br` | banco de homologação separado |
| PROD | `app.exemplo.com.br` | banco de produção, secrets de produção |

Nunca compartilhe banco ou secrets entre ambientes.

## Portabilidade

Nada na aplicação pode depender de estar rodando especificamente em TrueNAS, Cloudflare ou
qualquer provedor específico. O container roda igual em qualquer host Docker — TrueNAS hoje,
VPS/AWS/Azure/GCP/DigitalOcean amanhã. Ver [`MIGRATION-STANDARD.md`](./MIGRATION-STANDARD.md).
