const DEFAULT_API_URL = "http://localhost:3001";

export function getApiUrl(): string {
  const url = process.env.EXPO_PUBLIC_API_URL;
  return url && url.length > 0 ? url : DEFAULT_API_URL;
}

export function buildApiUrl(path: string): string {
  const base = getApiUrl().replace(/\/+$/, "");
  const suffix = path.startsWith("/") ? path : `/${path}`;
  return `${base}${suffix}`;
}
