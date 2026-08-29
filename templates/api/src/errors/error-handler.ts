import type { FastifyError, FastifyReply, FastifyRequest } from "fastify";
import { ZodError } from "zod";

/**
 * Centralized error handler. Never leaks stack traces or internal details to
 * the client; 5xx responses always return a generic message, real details go
 * only to the (non-sensitive) server log.
 */
export function errorHandler(error: FastifyError | ZodError, request: FastifyRequest, reply: FastifyReply): void {
  if (error instanceof ZodError) {
    request.log.warn({ err: error }, "validation failed");
    reply.status(400).send({
      error: {
        code: "VALIDATION_ERROR",
        message: error.issues[0]?.message ?? "invalid request",
      },
    });
    return;
  }

  const statusCode = error.statusCode ?? 500;

  if (statusCode >= 500) {
    request.log.error({ err: error }, "request failed");
  } else {
    request.log.warn({ err: error }, "request rejected");
  }

  reply.status(statusCode).send({
    error: {
      code: error.code ?? "INTERNAL_ERROR",
      message: statusCode >= 500 ? "internal server error" : error.message,
    },
  });
}
