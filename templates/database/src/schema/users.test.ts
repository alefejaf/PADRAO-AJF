import { describe, expect, it } from "vitest";
import { users } from "./users.js";

describe("users table", () => {
  it("exposes the expected columns", () => {
    expect(Object.keys(users)).toEqual(
      expect.arrayContaining(["id", "name", "email", "createdAt", "updatedAt"]),
    );
  });
});
