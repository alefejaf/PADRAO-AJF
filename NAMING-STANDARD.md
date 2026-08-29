# NAMING-STANDARD.md

Convenção de nomes usada por `create-project.ps1` e esperada em todo projeto PADRAO-AJF.

## Nome do projeto → slug

O slug é gerado a partir do nome informado: minúsculo, sem acentos, espaços e caracteres
inválidos viram `-`, sem `-` duplicado ou nas pontas.

```
"Gestão de Frota"  →  gestao-frota
```

## Containers

`docker-compose.yml` **não define `container_name:`** — o nome do projeto compose
(`name: {{PROJECT_SLUG}}`, no topo do arquivo) já nomeia os containers de forma previsível e
sem conflito (`{{PROJECT_SLUG}}-web-1`, `{{PROJECT_SLUG}}-api-1`, `{{PROJECT_SLUG}}-db-1`), sem
travar em nomes fixos caso o mesmo compose precise rodar mais de uma vez no mesmo host (outro
ambiente, um teste paralelo). Comandos continuam endereçando pelo **nome do serviço**, não pelo
nome do container:

```bash
docker compose logs api
docker compose exec db psql -U postgres
```

Só mantenha `container_name:` explícito se houver uma razão técnica concreta (uma ferramenta
externa que só aceita nome fixo de container, por exemplo) — documente o motivo ao lado.

## Imagens (GHCR)

```
ghcr.io/{{GHCR_OWNER}}/{{PROJECT_SLUG}}-web
ghcr.io/{{GHCR_OWNER}}/{{PROJECT_SLUG}}-api
```

Sempre com pelo menos duas tags por build: `latest` e o SHA do commit (ver
[`DEPLOY-STANDARD.md`](./DEPLOY-STANDARD.md#versionamento-de-imagens)).

## Rede e volumes Docker

```
{{PROJECT_SLUG}}-network
{{PROJECT_SLUG}}-postgres-data
{{PROJECT_SLUG}}-uploads-data      (quando o projeto usa storage de arquivos)
```

## Portas

Porta **interna** do container é sempre fixa (`web` = `3000`, `api` = `3001`) — é o que o
Dockerfile, o healthcheck e o código da aplicação esperam. Só a porta publicada no **host**
muda por projeto (`-WebPort`/`-ApiPort` do gerador, padrão `3000`/`3001`), para não colidir
quando vários projetos PADRAO-AJF rodam no mesmo servidor:

```
{{PROJECT_SLUG}}   → host 3100 (web) / 3101 (api)
outro-projeto      → host 3200 (web) / 3201 (api)
```

## Domínios

```
{{PROJECT_SLUG}}.exemplo.com.br        # web
api-{{PROJECT_SLUG}}.exemplo.com.br    # api
```

Exemplo real:

```
frota.exemplo.com.br
api-frota.exemplo.com.br
```

## Pacotes do workspace (pnpm)

```
apps/web     → package.json "name": "{{PROJECT_SLUG}}-web"
apps/api     → package.json "name": "{{PROJECT_SLUG}}-api"
apps/mobile  → package.json "name": "{{PROJECT_SLUG}}-mobile"

packages/shared     → "@{{PROJECT_SLUG}}/shared"
packages/database   → "@{{PROJECT_SLUG}}/database"
packages/api-client → "@{{PROJECT_SLUG}}/api-client"
```

Pacotes internos (`packages/*`) usam escopo `@{{PROJECT_SLUG}}/...` porque são consumidos via
`workspace:*` por outros pacotes. Apps (`apps/*`) não são importados por ninguém, então não
precisam de escopo.

## Variáveis de ambiente

`UPPER_SNAKE_CASE` sempre. Prefixos com significado especial:

- `NEXT_PUBLIC_*` — exposta ao browser pelo Next.js. Nunca um segredo.
- `EXPO_PUBLIC_*` — embutida no bundle do app mobile. Nunca um segredo.
- Tudo o mais sem prefixo especial é assumido como **só-servidor**.

## Branches Git (sugestão, não obrigatório)

```
main        # produção
develop     # integração (opcional, times pequenos podem viver só com main + PRs)
feat/*      # features
fix/*       # correções
```
