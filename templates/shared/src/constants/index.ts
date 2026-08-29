export const API_ROUTES = {
  health: "/health",
  version: "/version",
  example: "/example",
} as const;

export const USER_ROLES = {
  USER: "USER",
  MANAGER: "MANAGER",
  ADMIN: "ADMIN",
} as const;

export const DEFAULT_WEB_PORT = 3000;
export const DEFAULT_API_PORT = 3001;
