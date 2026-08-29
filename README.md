# PADRAO-AJF

Padrão oficial de desenvolvimento: uma base modular, reutilizável e portátil para novos
projetos (e para adaptar projetos existentes) — cobrindo desenvolvimento local, GitHub, Docker,
GHCR, TrueNAS + Cloudflare Tunnel hoje, e qualquer outro host Docker (VPS, AWS, Azure, GCP,
DigitalOcean) amanhã.

Este repositório não é só documentação: `templates/` tem código real e funcional, e
`scripts/create-project.ps1` gera projetos completos a partir dele.

## Estrutura

```
PADRAO-AJF/
├── templates/              # módulos reais e funcionais
│   ├── web/                 # Next.js + TypeScript
│   ├── api/                 # Fastify + TypeScript
│   ├── mobile/               # Expo (React Native) + TypeScript
│   ├── database/             # PostgreSQL + Drizzle ORM
│   └── shared/                # types, schemas Zod, constantes (+ api-client/)
│
├── scripts/
│   ├── create-project.ps1    # gerador de projetos
│   ├── validate-standard.ps1 # validação estática (PASS/WARN/FAIL)
│   └── test-generator.ps1    # gera e valida os 8 cenários de referência
│
├── infra-template/
│   └── github-workflows/     # ci.yml + docker-publish.yml usados por todo projeto gerado
│
├── docs/
│   ├── architecture/
│   ├── deploy/                # TRUENAS.md, TRUENAS-CLOUDFLARE.md
│   ├── security/
│   ├── backup/
│   └── migration/             # ADAPTAR-PROJETO-EXISTENTE.md
│
├── PROJECT-STANDARD.md        # leia antes de mexer em arquitetura/infra — inclui regras para IAs
├── ARCHITECTURE-STANDARD.md
├── DEPLOY-STANDARD.md
├── SECURITY-STANDARD.md
├── BACKUP-STANDARD.md
├── MIGRATION-STANDARD.md
├── NAMING-STANDARD.md
├── AUTH-STANDARD.md
├── DATABASE-STANDARD.md
├── TESTING-STANDARD.md
├── CHECKLIST-PRODUCAO.md
└── README.md                  # este arquivo
```

## Stack padrão

Web = Next.js · API = Fastify · Mobile = Expo (React Native) · Banco = PostgreSQL · ORM =
Drizzle · Validação = Zod · Monorepo = pnpm workspaces. Sem Turborepo por padrão. Detalhes e
justificativa em [`ARCHITECTURE-STANDARD.md`](./ARCHITECTURE-STANDARD.md).

## Gerando um projeto novo

Interativo:

```powershell
cd PADRAO-AJF
.\scripts\create-project.ps1
```

Por argumentos:

```powershell
.\scripts\create-project.ps1 -Name "gestao-frota" -Web -Api -Mobile -Database postgresql
.\scripts\create-project.ps1 -Name "site-institucional" -Web -Pwa -Database none
.\scripts\create-project.ps1 -Name "backoffice" -Web -Api -Database postgresql -Auth -Storage
.\scripts\create-project.ps1 -Name "frota" -Web -Api -Database postgresql -WebPort 3100 -ApiPort 3101
```

O gerador pergunta (ou recebe por flag): Web?, API separada?, App Mobile?, PWA?, Banco
(PostgreSQL embedded/external, Supabase ou Nenhum), Storage de arquivos?, Autenticação?, porta
Web/API? — e monta só as pastas que o projeto realmente precisa (ver o princípio modular em
[`ARCHITECTURE-STANDARD.md`](./ARCHITECTURE-STANDARD.md)). Mobile sem API é recusado —
Mobile nunca acessa o banco diretamente (no modo interativo a API é habilitada automaticamente
com aviso; por argumentos, `-Mobile` sem `-Api` para o script com erro).

Por padrão o projeto é gerado como pasta irmã do PADRAO-AJF (`-OutputPath` para escolher outro
lugar). O projeto gerado sai **autocontido**: já vem com sua própria cópia dos `*-STANDARD.md`
relevantes e de `scripts/validate-standard.ps1`, para continuar autoexplicativo (e
autovalidável) mesmo sem o PADRAO-AJF por perto.

## Validando um projeto

```powershell
.\scripts\validate-standard.ps1 -Path ..\gestao-frota
```

Roda checagens estáticas (não é um scanner de segurança completo): `.env` versionado,
possíveis segredos, IP privado hardcoded, placeholder `{{...}}` esquecido, senha/URL de banco
hardcoded no compose, porta de host duplicada, variável `NEXT_PUBLIC_*`/`EXPO_PUBLIC_*` com
nome de segredo, `package.json`/`pnpm-workspace.yaml` inválido, Dockerfile rodando como root,
arquivos essenciais ausentes, healthcheck ausente, e (quando o Docker está disponível)
`docker compose config`. Saída `PASS` / `WARN` / `FAIL` por checagem; todo projeto gerado já
roda isso automaticamente no CI (`ci.yml` e `docker-publish.yml`) — um `FAIL` impede a
publicação da imagem.

## Testando o gerador

```powershell
.\scripts\test-generator.ps1            # 8 cenários de referência, checagem estrutural
.\scripts\test-generator.ps1 -Full      # + pnpm install/lint/typecheck/test/build
.\scripts\test-generator.ps1 -DockerBuild  # + docker build de cada imagem
```

## Por onde começar a ler

1. [`PROJECT-STANDARD.md`](./PROJECT-STANDARD.md) — regras obrigatórias e regras para IA. Leia primeiro.
2. [`ARCHITECTURE-STANDARD.md`](./ARCHITECTURE-STANDARD.md) — por que a estrutura é modular, quando usar API separada.
3. Os demais `*-STANDARD.md` conforme a necessidade (segurança, banco, deploy, backup, auth, testes, nomes, checklist de produção, migração).
4. [`docs/migration/ADAPTAR-PROJETO-EXISTENTE.md`](./docs/migration/ADAPTAR-PROJETO-EXISTENTE.md) — se o objetivo é adaptar um projeto que já existe, não criar um novo.

## Princípios (resumo)

- Simplicidade e manutenção antes de qualquer tecnologia "porque é popular".
- API separada só quando há necessidade real (mobile, múltiplos consumidores, integração externa) — nunca por padrão.
- Nada de secret, IP privado ou credencial real em nenhum template — sempre placeholder.
- Todo projeto gerado nasce com Docker, healthcheck, CI, `.env.example` e README completos.
- Portabilidade: o mesmo container roda em TrueNAS, VPS ou qualquer nuvem com Docker.
