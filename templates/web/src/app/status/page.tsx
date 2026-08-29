import { headers } from "next/headers";
import type { HealthResponse } from "@{{PROJECT_SLUG}}/shared";
import { getServerApiBaseUrl } from "@/lib/api-url";
import { logger } from "@/lib/logger";

async function getOwnBaseUrl(): Promise<string> {
  const h = await headers();
  const host = h.get("x-forwarded-host") ?? h.get("host") ?? "localhost:3000";
  const protocol = h.get("x-forwarded-proto") ?? "http";
  return `${protocol}://${host}`;
}

async function fetchHealth(url: string): Promise<HealthResponse | { error: string }> {
  try {
    const response = await fetch(url, { cache: "no-store" });
    if (!response.ok) return { error: `HTTP ${response.status}` };
    return (await response.json()) as HealthResponse;
  } catch (error) {
    logger.error("status page health check failed", { url, error: String(error) });
    return { error: "unreachable" };
  }
}

export default async function StatusPage() {
  const baseUrl = await getOwnBaseUrl();
  const webHealth = await fetchHealth(`${baseUrl}/api/health`);

  // Server-side: prefere a rede interna do Docker (API_INTERNAL_URL) quando
  // existir; só cai para a URL pública se não houver rede interna.
  const apiUrl = getServerApiBaseUrl();
  const apiHealth = apiUrl ? await fetchHealth(`${apiUrl}/health`) : null;

  return (
    <main>
      <h1>Status</h1>

      <h2>Web</h2>
      <pre>{JSON.stringify(webHealth, null, 2)}</pre>

      {apiUrl ? (
        <>
          <h2>API</h2>
          <pre>{JSON.stringify(apiHealth, null, 2)}</pre>
        </>
      ) : (
        <p>Nenhuma API separada configurada (API_INTERNAL_URL/NEXT_PUBLIC_API_URL não definidas).</p>
      )}
    </main>
  );
}
