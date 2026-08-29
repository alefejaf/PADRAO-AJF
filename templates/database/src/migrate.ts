import "dotenv/config";
import { migrate } from "drizzle-orm/postgres-js/migrator";
import { createDb, closeDb } from "./client.js";

/**
 * Applies pending migrations from ./migrations.
 * Run explicitly (pnpm run migrate) — never automatically on app boot.
 * Destructive migrations (DROP TABLE/COLUMN, incompatible type changes) must be
 * reviewed manually before running this in production. See DATABASE-STANDARD.md.
 */
async function main() {
  const db = createDb();
  console.log("[migrate] applying pending migrations from ./migrations ...");
  await migrate(db, { migrationsFolder: "./migrations" });
  console.log("[migrate] done.");
  await closeDb();
}

main().catch((error) => {
  console.error("[migrate] failed:", error);
  process.exitCode = 1;
});
