import { exampleQuerySchema } from "@{{PROJECT_SLUG}}/shared";
import type { FastifyInstance } from "fastify";

/**
 * Demonstrates request validation with the schema shared with web/mobile.
 * Replace with real domain routes as the project grows.
 */
export async function exampleRoute(app: FastifyInstance): Promise<void> {
  app.get("/example", async (request) => {
    const { name } = exampleQuerySchema.parse(request.query);
    return { message: `hello, ${name ?? "world"}!` };
  });
}
