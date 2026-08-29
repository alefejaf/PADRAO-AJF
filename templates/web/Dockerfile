# Build com o contexto na RAIZ do monorepo:
#   docker build -f apps/web/Dockerfile -t {{PROJECT_SLUG}}-web \
#     --build-arg APP_VERSION=<versao> --build-arg GIT_COMMIT_SHA=<sha> .
#
# Usa o output "standalone" do Next.js: a imagem final não contém devDependencies
# nem o restante do monorepo, apenas o servidor Next mínimo já com as
# dependências de produção resolvidas.

FROM node:20-alpine AS base
RUN npm install -g pnpm@9
WORKDIR /app

FROM base AS workspace
COPY pnpm-workspace.yaml package.json pnpm-lock.yaml ./
COPY apps/web/package.json ./apps/web/package.json
COPY packages ./packages
COPY apps/web ./apps/web
RUN pnpm install --frozen-lockfile

FROM workspace AS build
ARG APP_VERSION=0.0.0
ARG GIT_COMMIT_SHA=unknown
ENV APP_VERSION=${APP_VERSION}
ENV GIT_COMMIT_SHA=${GIT_COMMIT_SHA}
ENV NEXT_TELEMETRY_DISABLED=1
# Só a imagem Docker (Linux) usa output "standalone" — build local (qualquer
# SO) usa o output padrão do Next, que nunca precisa de symlink. Ver
# next.config.mjs e DEPLOY-STANDARD.md#build-local-x-build-de-produção.
ENV NEXT_OUTPUT_STANDALONE=true
RUN pnpm --filter {{PROJECT_SLUG}}-web run build

FROM node:20-alpine AS runtime
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
RUN addgroup -S app && adduser -S app -G app
WORKDIR /app

COPY --from=build --chown=app:app /app/apps/web/.next/standalone ./
COPY --from=build --chown=app:app /app/apps/web/.next/static ./apps/web/.next/static
COPY --from=build --chown=app:app /app/apps/web/public ./apps/web/public

USER app

ARG APP_VERSION=0.0.0
ARG GIT_COMMIT_SHA=unknown
ENV APP_VERSION=${APP_VERSION}
ENV GIT_COMMIT_SHA=${GIT_COMMIT_SHA}
ENV PORT=3000
ENV HOSTNAME=0.0.0.0

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||3000)+'/api/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "apps/web/server.js"]
