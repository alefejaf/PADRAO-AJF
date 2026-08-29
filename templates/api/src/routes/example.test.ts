import { afterEach, describe, expect, it } from "vitest";
import type { FastifyInstance } from "fastify";
import { buildServer } from "../server.js";
import { loadEnv } from "../env.js";

let app: FastifyInstance | undefined;

afterEach(async () => {
  await app?.close();
  app = undefined;
});

// Força NODE_ENV=test para nunca usar o transport pino-pretty (que sobe uma
// worker thread) nos testes — evita lentidão/flakiness desnecessária.
function buildTestServer() {
  return buildServer(loadEnv({ ...process.env, NODE_ENV: "test" }));
}

describe("GET /health", () => {
  it("reports ok", async () => {
    app = await buildTestServer();
    const response = await app.inject({ method: "GET", url: "/health" });
    expect(response.statusCode).toBe(200);
    expect(response.json()).toMatchObject({ status: "ok" });
  });
});

describe("GET /example", () => {
  it("greets the given name", async () => {
    app = await buildTestServer();
    const response = await app.inject({ method: "GET", url: "/example?name=Ada" });
    expect(response.statusCode).toBe(200);
    expect(response.json()).toEqual({ message: "hello, Ada!" });
  });

  it("defaults to world when name is omitted", async () => {
    app = await buildTestServer();
    const response = await app.inject({ method: "GET", url: "/example" });
    expect(response.json()).toEqual({ message: "hello, world!" });
  });
});
