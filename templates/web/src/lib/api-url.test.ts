import { afterEach, describe, expect, it } from "vitest";
import { getServerApiBaseUrl } from "./api-url.js";

const ORIGINAL_ENV = { ...process.env };

afterEach(() => {
  process.env = { ...ORIGINAL_ENV };
});

describe("getServerApiBaseUrl", () => {
  it("prefers API_INTERNAL_URL over NEXT_PUBLIC_API_URL", () => {
    process.env.API_INTERNAL_URL = "http://api:3001";
    process.env.NEXT_PUBLIC_API_URL = "https://api.exemplo.com.br";
    expect(getServerApiBaseUrl()).toBe("http://api:3001");
  });

  it("falls back to NEXT_PUBLIC_API_URL when API_INTERNAL_URL is unset", () => {
    delete process.env.API_INTERNAL_URL;
    process.env.NEXT_PUBLIC_API_URL = "https://api.exemplo.com.br";
    expect(getServerApiBaseUrl()).toBe("https://api.exemplo.com.br");
  });

  it("returns undefined when neither is set", () => {
    delete process.env.API_INTERNAL_URL;
    delete process.env.NEXT_PUBLIC_API_URL;
    expect(getServerApiBaseUrl()).toBeUndefined();
  });
});
