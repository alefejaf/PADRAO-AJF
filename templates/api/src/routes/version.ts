import type { FastifyInstance } from "fastify";

export async function versionRoute(app: FastifyInstance): Promise<void> {
  app.get("/version", async () => ({
    version: process.env.APP_VERSION ?? "0.0.0",
    commit: process.env.GIT_COMMIT_SHA ?? "unknown",
  }));
}
