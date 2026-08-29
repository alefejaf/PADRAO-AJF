import { describe, expect, it, vi } from "vitest";
import { ApiClientError, createApiClient } from "./index.js";

function jsonResponse(body: unknown, ok = true, status = 200): Response {
  return {
    ok,
    status,
    json: async () => body,
  } as unknown as Response;
}

describe("createApiClient", () => {
  it("parses a valid health response", async () => {
    const fetchImpl = vi.fn().mockResolvedValue(
      jsonResponse({ status: "ok", service: "x-api", version: "0.1.0", timestamp: new Date().toISOString() }),
    );
    const client = createApiClient({ baseUrl: "http://localhost:3001", fetchImpl });
    const health = await client.getHealth();
    expect(health.status).toBe("ok");
  });

  it("throws ApiClientError on non-ok response", async () => {
    const fetchImpl = vi.fn().mockResolvedValue(jsonResponse({}, false, 500));
    const client = createApiClient({ baseUrl: "http://localhost:3001", fetchImpl });
    await expect(client.getHealth()).rejects.toBeInstanceOf(ApiClientError);
  });
});
