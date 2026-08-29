import cors from "@fastify/cors";
import helmet from "@fastify/helmet";
import rateLimit from "@fastify/rate-limit";
import type { FastifyInstance } from "fastify";
import type { Env } from "../env.js";

/**
 * Security baseline applied to every route: secure headers, CORS restricted to
 * known origins and a global rate limit. See SECURITY-STANDARD.md.
 */
export async function registerSecurityPlugins(app: FastifyInstance, env: Env): Promise<void> {
  await app.register(helmet);

  await app.register(cors, {
    origin: env.CORS_ORIGIN === "*" ? true : env.CORS_ORIGIN.split(",").map((origin) => origin.trim()),
  });

  await app.register(rateLimit, {
    max: env.RATE_LIMIT_MAX,
    timeWindow: env.RATE_LIMIT_WINDOW,
  });
}
