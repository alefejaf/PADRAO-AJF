# BACKUP-STANDARD.md

## Princípio

**Um backup só é válido se já foi restaurado com sucesso.** Backup que ninguém nunca testou
restaurar é uma suposição, não uma garantia. Backup no mesmo disco/servidor que os dados
originais **não é backup suficiente** — se o disco morre, os dois somem juntos.

## Estratégia inicial

| Frequência | O quê |
|---|---|
| Diário | Banco de dados (`pg_dump`) |
| Semanal | Arquivos (uploads / storage) |
| Mensal | Cópia adicional para um local diferente (outro disco, outro provedor, storage frio) |

Isso é o mínimo razoável para começar — projetos com dados críticos podem (e devem) aumentar a
frequência.

## Banco de dados

```bash
# backup (ajuste USER/DB se você customizou POSTGRES_USER/POSTGRES_DB no .env)
docker compose exec -T db pg_dump -U postgres {{PROJECT_SLUG_UNDERSCORE}} \
  | gzip > backup-{{PROJECT_SLUG}}-$(date +%Y%m%d).sql.gz

# restore (ambiente de teste, nunca direto em produção sem necessidade)
gunzip -c backup-{{PROJECT_SLUG}}-20260101.sql.gz \
  | docker compose exec -T db psql -U postgres {{PROJECT_SLUG_UNDERSCORE}}
```

Só se aplica quando o banco é **embedded** (o compose tem um serviço `db`). No modo
**external** (`-DatabaseMode external`), o backup é responsabilidade de quem opera o
PostgreSQL externo — confirme a política de backup dele separadamente. Ver
[`DATABASE-STANDARD.md#embedded-x-external`](./DATABASE-STANDARD.md#embedded-x-external).

Automatize isso com um cron simples no host (TrueNAS tem agendador de tarefas nativo) chamando
um script em `infra/scripts/`. Não precisa de uma ferramenta de backup dedicada para começar.

## Storage (arquivos)

Quando o projeto usa upload de arquivos (`-Storage` no gerador):

- Nunca trate o filesystem do container como o backup — ele é efêmero por definição.
- Use um volume Docker persistente (`{{PROJECT_SLUG}}-uploads-data`) **e** faça backup desse
  volume separadamente do container. O volume é montado em `/data/uploads` no serviço que
  efetivamente lida com upload — a API quando ela existe, senão o próprio Web (ver
  `ARCHITECTURE-STANDARD.md`) — não em ambos.
- Se usar storage externo (S3-compatible, Supabase Storage), o backup passa a ser
  responsabilidade do provedor — confirme a política de retenção dele mesmo assim.

## Onde guardar

- Backup do banco/arquivos: local diferente do servidor de produção (outro disco físico no
  TrueNAS, outro storage, ou um provedor de backup externo).
- Secrets usados no processo de backup/restore (credenciais de storage externo, por exemplo):
  cofre de segredos (1Password, Bitwarden, GitHub Encrypted Secrets) — nunca no repositório,
  nunca junto com o próprio backup.

## Restore — sempre documentado e sempre testado

Cada projeto deve manter, no seu próprio README ou num `infra/scripts/restore.sh`, o passo a
passo real de restore usado da última vez que foi testado. Um restore não documentado é, na
prática, um restore que não existe.

Checklist mínimo de um restore válido:

- [ ] o backup usado tem menos de 24h de defasagem (ou o aceitável definido pelo projeto);
- [ ] o restore foi feito num ambiente separado de produção (staging/local);
- [ ] a aplicação subiu normalmente contra o banco restaurado;
- [ ] um smoke test básico (login, CRUD principal) passou contra o banco restaurado.

## Ver também

- [`DATABASE-STANDARD.md`](./DATABASE-STANDARD.md)
- [`DEPLOY-STANDARD.md`](./DEPLOY-STANDARD.md#rollback)
- [`CHECKLIST-PRODUCAO.md`](./CHECKLIST-PRODUCAO.md)
