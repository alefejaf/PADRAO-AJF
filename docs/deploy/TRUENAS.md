# Implantação no TrueNAS (conceitual)

## Fluxo

```
GitHub
  ↓  (push)
GitHub Actions
  ↓  (build + test + docker build)
GHCR (ghcr.io/OWNER/projeto-*)
  ↓  (pull)
TrueNAS — Docker
  ↓
Cloudflare Tunnel
  ↓
Internet (HTTPS)
```

O TrueNAS entra só na penúltima etapa: ele roda os containers Docker (via app custom / Docker
Compose, dependendo da versão do TrueNAS) e nada mais. Build e publicação da imagem acontecem
no GitHub Actions, não no TrueNAS.

## Requisitos no host

- Docker (ou o Docker integrado do TrueNAS SCALE) disponível.
- Acesso ao GHCR para `docker pull` das imagens publicadas (repositório público, ou
  `docker login ghcr.io` com um token do GitHub que tenha permissão `read:packages`).
- Volumes persistentes já criados/nomeados conforme [`NAMING-STANDARD.md`](../../NAMING-STANDARD.md)
  (`{{PROJECT_SLUG}}-postgres-data`, `{{PROJECT_SLUG}}-uploads-data`).

## Regras

- **Nunca** coloque o IP do TrueNAS neste repositório ou em qualquer template — configuração de
  host é feita no `docker-compose.yml`/variáveis de ambiente do próprio servidor, fora do
  controle de versão da aplicação.
- Containers sobem com `restart: unless-stopped` — sobrevivem a reboot do host sem intervenção manual.
- Todo serviço com healthcheck (`HEALTHCHECK` no Dockerfile) — o TrueNAS/Docker usa isso para saber se o container está realmente pronto, não só "rodando".
- Banco de dados e qualquer serviço interno (Redis, etc.) **não** publicam porta para a rede local nem para a internet — só participam da rede Docker interna do projeto.
- A interface administrativa do próprio TrueNAS, SMB e SSH nunca ficam expostos à internet — acesso remoto ao TrueNAS em si é outro assunto (VPN/Tunnel dedicado), completamente separado do Cloudflare Tunnel da aplicação.

## Deploy (na prática)

```bash
# no TrueNAS, dentro da pasta do projeto
docker compose pull
docker compose up -d
docker compose ps          # confirma "healthy"
```

Para trocar de versão (rollback incluso), veja
[`DEPLOY-STANDARD.md#rollback`](../../DEPLOY-STANDARD.md#rollback) — é sempre uma troca de tag
de imagem seguida de `pull` + `up -d`, nunca uma reconstrução manual no servidor.

## Ver também

- [`TRUENAS-CLOUDFLARE.md`](./TRUENAS-CLOUDFLARE.md) — como o tráfego HTTPS chega até aqui.
- [`../../DEPLOY-STANDARD.md`](../../DEPLOY-STANDARD.md)
- [`../../MIGRATION-STANDARD.md`](../../MIGRATION-STANDARD.md) — sair do TrueNAS para outro host Docker no futuro.
