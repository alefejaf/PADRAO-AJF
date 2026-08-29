# PROJECT-STANDARD.md

> **LEIA ESTE ARQUIVO ANTES DE ALTERAR A ARQUITETURA OU INFRAESTRUTURA DESTE PROJETO.**

Este documento é a referência principal para qualquer pessoa — ou qualquer IA (Claude,
ChatGPT, Cursor, Antigravity ou outro agente) — que for mexer na arquitetura, infraestrutura,
build, deploy ou banco de dados de um projeto gerado a partir do **PADRAO-AJF**.

Ele acompanha o projeto gerado (foi copiado para a raiz pelo `create-project.ps1`) para que o
projeto continue autoexplicativo mesmo sem o PADRAO-AJF por perto.

## Regras obrigatórias

1. **Compatível com Docker.** Todo app com Web ou API precisa continuar buildando e rodando em container sem passos manuais extras.
2. **Sem IP hardcoded.** Endereços de servidor nunca vão direto no código — sempre variável de ambiente ou nome de serviço Docker.
3. **Sem secrets no código.** Toda credencial, chave ou token vive em variável de ambiente / secret manager — nunca em texto no repositório.
4. **`.env.example` obrigatório.** Toda variável usada precisa aparecer (com placeholder) em algum `.env.example`.
5. **Healthcheck.** Web e API expõem um endpoint de health e o Dockerfile declara `HEALTHCHECK`. Nunca remova.
6. **Logs em stdout/stderr.** Nunca em arquivo dentro do container.
7. **README atualizado.** Mudanças relevantes de arquitetura atualizam o `README.md`.
8. **Build de produção precisa passar.** `pnpm run build` é o gate mínimo antes de qualquer deploy.
9. **CI configurado.** `.github/workflows/ci.yml` roda lint, typecheck, test e build a cada push/PR.
10. **GHCR quando aplicável.** Web e API publicam imagem versionada no GHCR; mobile nunca publica no GHCR (usa EAS — ver `apps/mobile/README.md`).
11. **Banco versionado.** Todo schema vive em código (`packages/database/src/schema`), nunca só "no banco".
12. **Migrations.** Toda alteração estrutural gera migration. Nunca alterar produção manualmente.
13. **Rollback.** Sempre é possível voltar para a imagem/tag anterior. `latest` sozinho nunca é uma estratégia de rollback.
14. **Backup.** Banco e arquivos persistentes têm backup testado e restaurável (ver `BACKUP-STANDARD.md`).
15. **Restore testado.** Um backup só é válido se já foi restaurado com sucesso ao menos uma vez.
16. **Segurança por padrão.** CORS restrito, rate limiting, headers seguros, validação de entrada, autorização no backend (ver `SECURITY-STANDARD.md`).
17. **Portabilidade.** Nada aqui pode depender de um provedor específico (TrueNAS, VPS, AWS, etc.) para funcionar — troca de servidor é configuração, não reescrita.
18. **Não acoplar infraestrutura à aplicação.** Cloudflare, reverse proxy, orquestrador — tudo isso é infraestrutura em volta do container, não código dentro dele.
19. **Não criar API separada sem necessidade.** Um projeto Web simples usa Server Actions/Route Handlers do próprio Next.js. API só entra quando há mobile, múltiplos consumidores, integrações externas ou regra de negócio compartilhada.
20. **Mobile exige API separada.** Mobile nunca acessa o banco diretamente (`Mobile → HTTPS → API → Banco`) — o gerador recusa `-Mobile` sem `-Api`.
21. **Não adicionar dependência sem justificativa.** Cada biblioteca nova tem que resolver um problema real do projeto.
22. **Evitar overengineering.** Prefira a solução simples que seja profissional e segura à solução complexa "porque pode precisar um dia".
23. **Manter a arquitetura simples.** Três linhas parecidas são melhores que uma abstração prematura.
24. **Validar alterações.** Antes de considerar uma mudança pronta: lint, typecheck, test e build precisam passar — e `scripts/validate-standard.ps1` sem `FAIL`.
25. **Atualizar a documentação.** Mudança de comportamento sem atualização de doc é mudança incompleta.
26. **Preservar compatibilidade com migração futura.** Nada pode prender o projeto a um único servidor/nuvem — ver `MIGRATION-STANDARD.md`.

## Regras para IA

Se você é uma IA (Claude, ChatGPT, Cursor, Antigravity ou qualquer outro agente) trabalhando
neste projeto, antes de propor ou aplicar uma mudança estrutural você deve:

- Ler este arquivo e os demais `*-STANDARD.md` na raiz antes de mudanças estruturais.
- Preservar os padrões aqui descritos — não "melhorar" a arquitetura por conta própria.
- Não introduzir secrets (nem de exemplo com aparência real) no código ou em commits.
- Não introduzir IP fixo — sempre variável de ambiente ou nome de serviço.
- Não remover healthcheck de Dockerfile ou docker-compose.
- Não quebrar o build Docker (multi-stage, usuário não-root, imagem enxuta).
- Não quebrar migrations existentes (nunca editar uma migration já aplicada — crie uma nova).
- Atualizar o `README.md` quando a mudança afetar como o projeto é instalado, rodado ou operado.
- Executar lint, testes, build e `scripts/validate-standard.ps1` antes de reportar uma tarefa como concluída.
- Relatar pendências explicitamente (o que não foi validado, o que precisa de decisão humana) em vez de presumir que está tudo pronto.
- Evitar mudanças desnecessárias — mexer só no que a tarefa pede.

## Ver também

- [`ARCHITECTURE-STANDARD.md`](./ARCHITECTURE-STANDARD.md) — princípio modular, stack, quando usar API separada.
- [`SECURITY-STANDARD.md`](./SECURITY-STANDARD.md) — segurança.
- [`DATABASE-STANDARD.md`](./DATABASE-STANDARD.md) — banco e migrations.
- [`DEPLOY-STANDARD.md`](./DEPLOY-STANDARD.md) — Docker, GHCR, CI/CD, rollback, ambientes.
- [`BACKUP-STANDARD.md`](./BACKUP-STANDARD.md) — backup e restore.
- [`AUTH-STANDARD.md`](./AUTH-STANDARD.md) — autenticação e autorização.
- [`TESTING-STANDARD.md`](./TESTING-STANDARD.md) — testes.
- [`NAMING-STANDARD.md`](./NAMING-STANDARD.md) — convenção de nomes.
- [`MIGRATION-STANDARD.md`](./MIGRATION-STANDARD.md) — migração para outro servidor/nuvem, adaptação de projeto existente.
- [`CHECKLIST-PRODUCAO.md`](./CHECKLIST-PRODUCAO.md) — checklist antes de ir para produção.
