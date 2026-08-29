import { healthResponseSchema, type HealthResponse } from "@{{PROJECT_SLUG}}/shared";

export class ApiClientError extends Error {
  status?: number;

  constructor(message: string, status?: number) {
    super(message);
    this.name = "ApiClientError";
    this.status = status;
  }
}

export interface ApiClientOptions {
  baseUrl: string;
  fetchImpl?: typeof fetch;
}

/**
 * Thin, typed wrapper around the API. Every response is validated at runtime
 * with the same Zod schemas the API uses, so a client never trusts an
 * unvalidated payload — see AUTH-STANDARD.md / SECURITY-STANDARD.md.
 */
export function createApiClient(options: ApiClientOptions) {
  const baseUrl = options.baseUrl.replace(/\/+$/, "");
  const doFetch = options.fetchImpl ?? fetch;

  async function get<T>(path: string): Promise<T> {
    let response: Response;
    try {
      response = await doFetch(`${baseUrl}${path}`);
    } catch {
      throw new ApiClientError("network request failed");
    }
    if (!response.ok) {
      throw new ApiClientError(`request failed with status ${response.status}`, response.status);
    }
    return (await response.json()) as T;
  }

  return {
    async getHealth(): Promise<HealthResponse> {
      return healthResponseSchema.parse(await get<HealthResponse>("/health"));
    },
    async getVersion(): Promise<{ version: string; commit: string }> {
      return get<{ version: string; commit: string }>("/version");
    },
    async example(name?: string): Promise<{ message: string }> {
      const query = name ? `?name=${encodeURIComponent(name)}` : "";
      return get<{ message: string }>(`/example${query}`);
    },
  };
}

export type ApiClient = ReturnType<typeof createApiClient>;
