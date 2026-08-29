import { describe, expect, it } from "vitest";
import { buildApiUrl } from "./config.js";

describe("buildApiUrl", () => {
  it("joins base url and path", () => {
    expect(buildApiUrl("/health")).toMatch(/\/health$/);
    expect(buildApiUrl("health")).toMatch(/\/health$/);
  });

  it("never produces a double slash between base and path", () => {
    expect(buildApiUrl("/health")).not.toMatch(/[^:]\/\//);
  });
});
