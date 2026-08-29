# CHECKLIST-PRODUCAO.md

Checklist mínimo antes de qualquer projeto PADRAO-AJF ir para produção pela primeira vez (ou
antes de um deploy relevante). `scripts/validate-standard.ps1` automatiza boa parte das
checagens estáticas; o resto é manual.

- [ ] instalação funciona (`pnpm install` limpo)
- [ ] `scripts/validate-standard.ps1` sem `FAIL` (WARN é aceitável, mas revisado)
- [ ] lint passa (`pnpm run lint`)
- [ ] testes passam (`pnpm run test`)
- [ ] build passa (`pnpm run build`)
- [ ] Docker build passa (`docker build` de cada app com Dockerfile)
- [ ] `.env` da raiz criado com `POSTGRES_PASSWORD` (embedded) ou `DATABASE_URL` (external) reais
- [ ] `docker compose config` passa com o `.env` real (compose sintaticamente válido)
- [ ] container inicia (`docker compose up`)
- [ ] healthcheck passa (`docker compose ps` mostra `healthy`)
- [ ] banco conecta (API sobe sem erro de `DATABASE_URL`)
- [ ] migrations verificadas (`pnpm run db:check`, schema em código bate com o banco)
- [ ] Web acessa API quando aplicável (`/status` mostra os dois healthchecks OK)
- [ ] Mobile acessa API quando aplicável (tela inicial mostra status da API) — usando a URL
      **pública** da API, nunca `localhost` nem `http://api:3001`
- [ ] `-WebPort`/`-ApiPort` não colidem com outro projeto já rodando no mesmo servidor
- [ ] API pública (`-PublicApi`) só ligada quando há Mobile ou consumidor fora do compose
- [ ] env documentado (`.env.example` cobre todas as variáveis usadas)
- [ ] nenhum secret no Git (`scripts/validate-standard.ps1`)
- [ ] nenhum IP privado hardcoded (`scripts/validate-standard.ps1`)
- [ ] nenhum placeholder `{{...}}` esquecido (`scripts/validate-standard.ps1`)
- [ ] logs funcionando (stdout/stderr, sem credenciais)
- [ ] restart configurado (`restart: unless-stopped` nos serviços)
- [ ] volumes persistentes identificados (banco, uploads)
- [ ] backup documentado e testado (ver `BACKUP-STANDARD.md`)
- [ ] restore documentado e testado
- [ ] rollback documentado (ver `DEPLOY-STANDARD.md#rollback`) — inclusive o caso em que
      rollback de container não resolve sozinho (`DEPLOY-STANDARD.md#rollback-e-banco`)
- [ ] GitHub Actions válido (workflow roda verde num push de teste)
- [ ] GHCR configurado (imagem aparece em `ghcr.io/OWNER/...`)
- [ ] banco não exposto publicamente (sem `ports:` do Postgres no compose de produção)
- [ ] README atualizado
- [ ] smoke test executado (ver `TESTING-STANDARD.md#3-smoke-test-pós-deploy`)
