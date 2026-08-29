import { z } from "zod";

/**
 * Zod schemas shared between web, api and mobile.
 * These are the single source of truth for request/response validation.
 */

export const healthResponseSchema = z.object({
  status: z.literal("ok"),
  service: z.string(),
  version: z.string(),
  timestamp: z.string(),
});

export type HealthResponse = z.infer<typeof healthResponseSchema>;

export const userRoleSchema = z.enum(["USER", "MANAGER", "ADMIN"]);

export type UserRole = z.infer<typeof userRoleSchema>;

export const userSchema = z.object({
  id: z.string().uuid(),
  name: z.string().min(1).max(120),
  email: z.string().email(),
  createdAt: z.string(),
  updatedAt: z.string(),
});

export type User = z.infer<typeof userSchema>;

export const createUserSchema = z.object({
  name: z.string().min(1, "name is required").max(120),
  email: z.string().email("invalid email"),
});

export type CreateUserInput = z.infer<typeof createUserSchema>;

export const exampleQuerySchema = z.object({
  name: z.string().min(1).max(60).optional(),
});

export type ExampleQuery = z.infer<typeof exampleQuerySchema>;
