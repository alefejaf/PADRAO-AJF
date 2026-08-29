type Level = "debug" | "info" | "warn" | "error";

const levelOrder: Record<Level, number> = { debug: 0, info: 1, warn: 2, error: 3 };
const currentLevel = (process.env.LOG_LEVEL as Level) || "info";

/**
 * Minimal structured logger writing to stdout/stderr (never to a file).
 * Kept intentionally dependency-free; swap for pino if the project needs more.
 */
function log(level: Level, message: string, context?: Record<string, unknown>) {
  if (levelOrder[level] < levelOrder[currentLevel]) return;
  const entry = {
    timestamp: new Date().toISOString(),
    level,
    service: "{{PROJECT_SLUG}}-web",
    message,
    ...(context ? { context } : {}),
  };
  const writer = level === "error" ? console.error : level === "warn" ? console.warn : console.log;
  writer(JSON.stringify(entry));
}

export const logger = {
  debug: (message: string, context?: Record<string, unknown>) => log("debug", message, context),
  info: (message: string, context?: Record<string, unknown>) => log("info", message, context),
  warn: (message: string, context?: Record<string, unknown>) => log("warn", message, context),
  error: (message: string, context?: Record<string, unknown>) => log("error", message, context),
};
