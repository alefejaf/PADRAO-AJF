# TESTING-STANDARD.md

Três níveis. Nenhum projeto é obrigado a ter os três desde o primeiro dia, mas todo projeto
gerado já sai com pelo menos o nível unitário funcionando (Vitest, configurado em cada
app/pacote).

## 1. Unitário

O que testar: validações (schemas Zod), regras de negócio puras, funções utilitárias.
Roda rápido, sem rede, sem banco, sem servidor de verdade.

```bash
pnpm run test               # todos os pacotes/apps
pnpm --filter {{PROJECT_SLUG}}-api run test   # só um
```

Exemplos já presentes nos templates: validação do `createUserSchema` (`packages/shared`),
rotas da API testadas via `fastify.inject` sem abrir porta (`apps/api`), helper de URL do
cliente mobile (`apps/mobile`).

## 2. Integração

O que testar: API completa (rota → validação → banco), interação real com PostgreSQL.

Recomendado: subir um Postgres descartável (`docker compose up db` ou um container efêmero) e
rodar os testes de integração contra ele — nunca contra o banco de desenvolvimento com dados
reais, e nunca contra produção.

Não é gerado automaticamente pelo `create-project.ps1` (depende demais do domínio de cada
projeto) — adicione conforme o projeto cresce, seguindo o mesmo padrão dos testes unitários
(Vitest) para não introduzir uma segunda ferramenta de teste sem necessidade.

## 3. Smoke test (pós-deploy)

Depois de qualquer deploy, confirme o mínimo de que o sistema está de pé:

- [ ] `GET /health` (API) e/ou `GET /api/health` (Web) respondem `200` com `status: "ok"`.
- [ ] Login funciona, quando o projeto tem autenticação.
- [ ] A rota/página principal carrega.
- [ ] Web consegue falar com a API (página `/status` mostra os dois healthchecks).

Isso pode ser manual (checklist) ou um script simples em `infra/scripts/smoke-test.sh` fazendo
`curl` nos endpoints acima — não precisa de um framework de E2E para isso.

## O que evitar

- **Não** exigir E2E pesado (Playwright/Cypress rodando fluxo completo de UI) em todo projeto
  por padrão — isso é justificável para produtos grandes com UI complexa, não para o projeto
  típico gerado por este padrão. Adicione quando o projeto realmente precisar.
- **Não** testar mocks de banco como se fossem o banco real em testes que decidem "esse deploy
  é seguro" — testes de integração usam PostgreSQL de verdade (mesmo que descartável), senão
  divergência entre mock e comportamento real do Postgres pode mascarar bugs.

## CI

`.github/workflows/ci.yml` roda `scripts/validate-standard.ps1` (falha o job em `FAIL`) e
depois `lint`, `typecheck`, `test` e `build` em todo push/PR. Os testes de integração (quando
existirem) devem rodar num job separado que sobe um serviço `postgres` no próprio workflow do
GitHub Actions.

## Testando o próprio gerador

O PADRAO-AJF tem seu próprio teste automatizado — `scripts/test-generator.ps1` — que gera os 8
cenários de referência (Web só, Web+Postgres embedded/external, Web+API+Postgres, Web+API+
Supabase, Web+API+Mobile+Postgres, Web+PWA, API só+Postgres) e roda `validate-standard.ps1` em
cada um; com `-Full`, também `pnpm install/lint/typecheck/test/build` e `docker compose
config`; com `-DockerBuild`, também builda as imagens Docker. Use isso antes de alterar
`create-project.ps1` ou os templates, para confirmar que nenhuma combinação quebrou.

## Ver também

- [`CHECKLIST-PRODUCAO.md`](./CHECKLIST-PRODUCAO.md)
- [`DEPLOY-STANDARD.md`](./DEPLOY-STANDARD.md)
