# Build com o contexto na RAIZ do monorepo:
#   docker build -f apps/api/Dockerfile -t {{PROJECT_SLUG}}-api .
#
# Multi-stage: instala o workspace completo, isola apenas o pacote "api" com
# suas dependências de produção (via `pnpm deploy`) e roda em uma imagem final
# mínima, sem devDependencies e sem código-fonte de outros pacotes.

FROM node:20-alpine AS base
RUN npm install -g pnpm@9
WORKDIR /app

FROM base AS workspace
COPY pnpm-workspace.yaml package.json pnpm-lock.yaml ./
COPY apps/api/package.json ./apps/api/package.json
COPY packages ./packages
COPY apps/api ./apps/api
RUN pnpm install --frozen-lockfile

FROM workspace AS build
RUN pnpm --filter {{PROJECT_SLUG}}-api run build
RUN pnpm --filter {{PROJECT_SLUG}}-api deploy --prod /app/deploy

FROM node:20-alpine AS runtime
ENV NODE_ENV=production
RUN addgroup -S app && adduser -S app -G app
WORKDIR /app
COPY --from=build --chown=app:app /app/deploy ./
USER app

ARG APP_VERSION=0.0.0
ARG GIT_COMMIT_SHA=unknown
ENV APP_VERSION=${APP_VERSION}
ENV GIT_COMMIT_SHA=${GIT_COMMIT_SHA}
ENV PORT=3001
ENV HOST=0.0.0.0

EXPOSE 3001

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||3001)+'/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "--import", "tsx", "src/index.ts"]
