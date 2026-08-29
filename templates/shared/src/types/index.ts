export type { HealthResponse, User, UserRole, CreateUserInput, ExampleQuery } from "../schemas/index.js";

/**
 * Generic API error shape returned by the API on failures.
 * Kept intentionally small: message + machine-readable code.
 */
export interface ApiErrorBody {
  error: {
    code: string;
    message: string;
  };
}
