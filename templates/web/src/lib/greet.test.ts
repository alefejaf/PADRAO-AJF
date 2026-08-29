import { describe, expect, it } from "vitest";
import { buildGreeting } from "./greet.js";

describe("buildGreeting", () => {
  it("greets the given name", () => {
    expect(buildGreeting({ name: "Ada" })).toEqual({ message: "hello, Ada!" });
  });

  it("defaults to world when no name is given", () => {
    expect(buildGreeting({})).toEqual({ message: "hello, world!" });
  });

  it("rejects an invalid name", () => {
    expect(() => buildGreeting({ name: "" })).toThrow();
  });
});
