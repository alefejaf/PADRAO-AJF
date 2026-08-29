# MIGRATION-STANDARD.md

Este documento cobre dois cenários diferentes de "migração" — não confunda os dois:

1. **Migrar a infraestrutura** de um projeto PADRAO-AJF para outro servidor/nuvem (este arquivo).
2. **Adaptar um projeto já existente** (que não nasceu no PADRAO-AJF) para seguir este padrão — procedimento detalhado em [`docs/migration/ADAPTAR-PROJETO-EXISTENTE.md`](./docs/migration/ADAPTAR-PROJETO-EXISTENTE.md).

## Por que isso é simples aqui

Todo projeto gerado pelo PADRAO-AJF já nasce portátil por construção:

- a aplicação só fala HTTP numa porta interna — nunca sabe se está atrás de Cloudflare, Nginx, Traefik ou nada;
- toda configuração é variável de ambiente — nada hardcoded que prenda o projeto a um host específico;
- o banco é PostgreSQL padrão (ou Supabase, que já é externo por natureza) — não um serviço proprietário do provedor atual;
- o build é uma imagem Docker padrão — roda igual em qualquer engine Docker compatível.

Por isso, trocar TrueNAS por uma VPS, AWS, Azure, Google Cloud ou DigitalOcean é uma mudança de
**onde** o container roda, não uma reescrita de código.

## Procedimento de migração de servidor

1. **Levante o estado atual**: quais containers rodam, quais volumes existem, quais variáveis de ambiente estão em uso (sem copiar os valores secretos para fora do cofre de segredos).
2. **Backup completo** antes de qualquer coisa (banco + arquivos) — ver [`BACKUP-STANDARD.md`](./BACKUP-STANDARD.md). Confirme que o backup restaura antes de prosseguir.
3. **Provisione o novo host** com Docker instalado e a mesma rede/volumes nomeados (ver [`NAMING-STANDARD.md`](./NAMING-STANDARD.md)).
4. **Restaure o banco** no novo host a partir do backup.
5. **Configure as variáveis de ambiente** no novo host (a partir do `.env.example`, com os valores reais vindos do cofre de segredos — nunca copiados de um `.env` antigo por e-mail/chat).
6. **Suba os containers** (`docker compose pull && docker compose up -d`) usando a mesma tag de imagem (SHA/versão) que estava em produção no host antigo.
7. **Rode o smoke test** (ver [`TESTING-STANDARD.md`](./TESTING-STANDARD.md#3-smoke-test-pós-deploy)) contra o novo host antes de apontar o domínio para ele.
8. **Troque o roteamento externo** (Cloudflare Tunnel / DNS / reverse proxy) para o novo host.
9. **Mantenha o host antigo de pé por um período de segurança** antes de desligá-lo, caso seja preciso reverter rapidamente.

## O que nunca deve travar uma migração

Se algum destes itens travar a migração, é sinal de que algo fugiu do padrão e precisa ser
corrigido antes (não durante) a migração:

- IP hardcoded em algum lugar do código ou de um `.env` versionado por engano.
- Dependência de um recurso proprietário do provedor atual sem equivalente documentado (ex.: um serviço gerenciado que só existe naquele provedor).
- Segredos que só existem "na cabeça de alguém" e não num cofre de segredos.
- Ausência de backup restaurável.

## Ver também

- [`docs/migration/ADAPTAR-PROJETO-EXISTENTE.md`](./docs/migration/ADAPTAR-PROJETO-EXISTENTE.md) — adaptar um projeto legado ao padrão, fase por fase.
- [`DEPLOY-STANDARD.md`](./DEPLOY-STANDARD.md)
- [`BACKUP-STANDARD.md`](./BACKUP-STANDARD.md)
