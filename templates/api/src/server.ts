import Fastify, { type FastifyInstance } from "fastify";
import { loadEnv, type Env } from "./env.js";
import { errorHandler } from "./errors/error-handler.js";
import { registerSecurityPlugins } from "./plugins/security.js";
import { exampleRoute } from "./routes/example.js";
import { healthRoute } from "./routes/health.js";
import { versionRoute } from "./routes/version.js";

export async function buildServer(
  env: Env = loadEnv(),
): Promise<FastifyInstance> {
  const isDevelopment = env.NODE_ENV === "development";

  const app = Fastify({
    logger: isDevelopment
      ? {
          level: env.LOG_LEVEL,
          transport: {
            target: "pino-pretty",
            options: {
              colorize: true,
              translateTime: "SYS:standard",
              ignore: "pid,hostname",
            },
          },
        }
      : {
          level: env.LOG_LEVEL,
        },
  });

  await registerSecurityPlugins(app, env);

  app.setErrorHandler(errorHandler);

  await app.register(healthRoute);
  await app.register(versionRoute);
  await app.register(exampleRoute);

  return app;
}