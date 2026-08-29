import { describe, expect, it } from "vitest";
import { createUserSchema, healthResponseSchema } from "./index.js";

describe("createUserSchema", () => {
  it("accepts a valid payload", () => {
    const result = createUserSchema.safeParse({ name: "Ada Lovelace", email: "ada@example.com" });
    expect(result.success).toBe(true);
  });

  it("rejects an invalid email", () => {
    const result = createUserSchema.safeParse({ name: "Ada", email: "not-an-email" });
    expect(result.success).toBe(false);
  });
});

describe("healthResponseSchema", () => {
  it("accepts a well formed health payload", () => {
    const result = healthResponseSchema.safeParse({
      status: "ok",
      service: "example-web",
      version: "0.1.0",
      timestamp: new Date().toISOString(),
    });
    expect(result.success).toBe(true);
  });
});
