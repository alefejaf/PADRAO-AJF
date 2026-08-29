# Adaptar um projeto existente ao PADRAO-AJF

Procedimento para levar um projeto que **já existe** (e não nasceu no PADRAO-AJF) a seguir este
padrão, sem reescrever a aplicação no processo.

> **Regra crítica:** não aproveite a migração de infraestrutura para reescrever regras de
> negócio sem necessidade. Primeiro estabilize a infraestrutura (Docker, CI, deploy, backup).
> Só depois — em outro momento, outro escopo — evolua a aplicação em si.

Este é um procedimento manual e assistido (feito por um dev, com ou sem ajuda de uma IA
seguindo [`PROJECT-STANDARD.md`](../../PROJECT-STANDARD.md)) — **não** é executado por um
script automático, porque cada projeto legado tem particularidades próprias.

## FASE 1 — Inventário

Levante, sem alterar nada ainda:

- stack (linguagem, framework, versões);
- estrutura de pastas atual;
- banco de dados (motor, versão, tamanho aproximado);
- como autenticação/autorização funciona hoje;
- se há upload/storage de arquivos, e onde eles ficam salvos hoje;
- como o deploy é feito hoje (manual? script? já usa Docker?);
- quais integrações externas existem (pagamento, e-mail, APIs de terceiros);
- quais variáveis de ambiente/configuração existem hoje e onde estão guardadas;
- qual(is) domínio(s) o projeto usa hoje.

## FASE 2 — Diagnóstico

A partir do inventário, identifique riscos antes de tocar em produção:

- hardcodes (IP, domínio, credencial) espalhados pelo código;
- secrets commitados no histórico do Git (não só no código atual — no histórico também);
- dependências muito desatualizadas ou sem manutenção;
- dados persistentes críticos (o que **não pode** ser perdido durante a migração);
- pontos únicos de falha (algo que só existe numa máquina, sem backup).

## FASE 3 — Containerização

- Escreva o Dockerfile (multi-stage, seguindo [`DEPLOY-STANDARD.md`](../../DEPLOY-STANDARD.md)) sem mudar o comportamento da aplicação.
- Escreva o `docker-compose.yml` para rodar localmente igual ao ambiente atual.
- Extraia toda configuração hardcoded para variáveis de ambiente + `.env.example`.
- Adicione um endpoint de healthcheck se o projeto ainda não tiver um.

Valide: a aplicação containerizada precisa se comportar **exatamente igual** à versão não
containerizada antes de seguir para a próxima fase.

## FASE 4 — Banco

- Se o schema não é versionado em código, comece a versioná-lo a partir de agora (não precisa
  recriar o histórico inteiro — um "schema inicial" que reflete o estado atual já é um bom
  ponto de partida com Drizzle, ver [`DATABASE-STANDARD.md`](../../DATABASE-STANDARD.md)).
- Configure backup (ver [`BACKUP-STANDARD.md`](../../BACKUP-STANDARD.md)) **antes** de qualquer
  mudança estrutural no banco de produção.
- Teste o restore antes de prosseguir.

## FASE 5 — CI/CD

- Adicione GitHub Actions (`ci.yml` + `docker-publish.yml`, ver [`DEPLOY-STANDARD.md`](../../DEPLOY-STANDARD.md)).
- Configure publicação de imagem no GHCR com tags `latest` + SHA.

## FASE 6 — Servidor

- Provisione volumes persistentes nomeados (ver [`NAMING-STANDARD.md`](../../NAMING-STANDARD.md)).
- Configure `restart: unless-stopped` e healthcheck no ambiente real (TrueNAS ou outro host Docker).

## FASE 7 — Acesso externo

- Configure HTTPS via Cloudflare Tunnel ou outro reverse proxy (ver [`docs/deploy/TRUENAS-CLOUDFLARE.md`](../deploy/TRUENAS-CLOUDFLARE.md)) — mantendo o domínio atual do projeto, se já existir um em produção.

## FASE 8 — Validação

Antes de considerar a migração concluída, confirme contra o ambiente migrado:

- [ ] login funciona (quando aplicável);
- [ ] CRUD principal funciona;
- [ ] dados do banco batem com o que existia antes;
- [ ] arquivos/uploads existentes continuam acessíveis;
- [ ] integrações externas continuam funcionando;
- [ ] smoke test completo (ver [`TESTING-STANDARD.md`](../../TESTING-STANDARD.md#3-smoke-test-pós-deploy)).

## FASE 9 — Rollback

Tenha um plano de voltar ao ambiente antigo **antes** de trocar produção de vez — mantenha o
ambiente/servidor antigo de pé até ter confiança real no novo (ver
[`MIGRATION-STANDARD.md`](../../MIGRATION-STANDARD.md)).

## Resumo do que nunca fazer durante essa migração

- Reescrever regra de negócio "já que estou mexendo mesmo".
- Trocar de banco de dados no mesmo passo em que containeriza (uma mudança de cada vez).
- Apontar produção para o ambiente novo sem smoke test.
- Migrar sem backup restaurável do estado anterior.
