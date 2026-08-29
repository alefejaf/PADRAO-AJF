/**
 * URL da API a partir do SERVIDOR (Server Actions, Route Handlers, Server
 * Components). Prefere API_INTERNAL_URL (endereço interno do Docker, ex.:
 * "http://api:3001", só resolve dentro da rede do compose) e cai para
 * NEXT_PUBLIC_API_URL quando não há rede interna (ex.: `pnpm run dev` sem
 * Docker, ou API hospedada fora deste compose).
 *
 * NUNCA use esta função em código que roda no browser — lá o único endereço
 * que existe é NEXT_PUBLIC_API_URL (leia-o diretamente). Ver env.ts e
 * DEPLOY-STANDARD.md.
 */
export function getServerApiBaseUrl(): string | undefined {
  return process.env.API_INTERNAL_URL ?? process.env.NEXT_PUBLIC_API_URL;
}
