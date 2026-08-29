import type { HealthResponse } from "@{{PROJECT_SLUG}}/shared";
import { buildApiUrl } from "./config.js";

export class ApiError extends Error {
  status?: number;

  constructor(message: string, status?: number) {
    super(message);
    this.name = "ApiError";
    this.status = status;
  }
}

async function request<T>(path: string): Promise<T> {
  let response: Response;
  try {
    response = await fetch(buildApiUrl(path));
  } catch {
    throw new ApiError("falha de rede ao chamar a API");
  }

  if (!response.ok) {
    throw new ApiError(`a API respondeu com status ${response.status}`, response.status);
  }

  return (await response.json()) as T;
}

export function getHealth(): Promise<HealthResponse> {
  return request<HealthResponse>("/health");
}
