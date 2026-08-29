import { healthResponseSchema } from "@{{PROJECT_SLUG}}/shared";
import type { FastifyInstance } from "fastify";

export async function healthRoute(app: FastifyInstance): Promise<void> {
  app.get("/health", async () => {
    return healthResponseSchema.parse({
      status: "ok",
      service: "{{PROJECT_SLUG}}-api",
      version: process.env.APP_VERSION ?? "0.0.0",
      timestamp: new Date().toISOString(),
    });
  });
}
