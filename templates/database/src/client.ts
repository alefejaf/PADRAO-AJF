import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import * as schema from "./schema/index.js";

function requireDatabaseUrl(): string {
  const url = process.env.DATABASE_URL;
  if (!url) {
    throw new Error("DATABASE_URL is not set. Copy .env.example to .env and configure it.");
  }
  return url;
}

let queryClient: ReturnType<typeof postgres> | undefined;

/**
 * Lazily creates a single shared postgres connection pool per process.
 * Avoids exhausting connections when this module is imported multiple times (dev hot-reload).
 */
export function getQueryClient() {
  if (!queryClient) {
    queryClient = postgres(requireDatabaseUrl(), { max: 10 });
  }
  return queryClient;
}

export function createDb() {
  return drizzle(getQueryClient(), { schema });
}

export const db = createDb();

export async function closeDb(): Promise<void> {
  if (queryClient) {
    await queryClient.end({ timeout: 5 });
    queryClient = undefined;
  }
}
