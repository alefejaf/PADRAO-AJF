import { z } from "zod";

const envSchema = z.object({
  NODE_ENV: z.enum(["development", "production", "test"]).default("development"),
  LOG_LEVEL: z.enum(["debug", "info", "warn", "error"]).default("info"),
  // Pública: usada pelo BROWSER. Precisa ser uma URL alcançável de fora do
  // Docker (HTTPS em produção) — nunca "http://api:3001" nem localhost.
  NEXT_PUBLIC_API_URL: z.string().url().optional(),
  // Só-servidor: usada por Server Actions/Route Handlers/Server Components
  // quando web e api rodam no mesmo docker-compose (ex.: "http://api:3001").
  // Quando ausente, o servidor cai para NEXT_PUBLIC_API_URL — ver
  // src/lib/api-url.ts.
  API_INTERNAL_URL: z.string().url().optional(),
  APP_VERSION: z.string().default("0.0.0"),
  GIT_COMMIT_SHA: z.string().default("local"),
});

export type Env = z.infer<typeof envSchema>;

/**
 * Server-only env accessor. Do not import this from a "use client" component —
 * on the client only NEXT_PUBLIC_* vars exist and the rest would fail validation.
 */
export function loadEnv(source: NodeJS.ProcessEnv = process.env): Env {
  const parsed = envSchema.safeParse(source);
  if (!parsed.success) {
    console.error("Invalid environment variables:", parsed.error.flatten().fieldErrors);
    throw new Error("invalid environment configuration");
  }
  return parsed.data;
}
