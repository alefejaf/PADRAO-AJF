import path from "path";
import { fileURLToPath } from "url";

const __dirname = fileURLToPath(new URL(".", import.meta.url));

// O output "standalone" faz o Next copiar as dependências de produção
// traçadas para .next/standalone — e essa cópia usa symlinks. Dentro do
// Dockerfile (Linux) isso é normal; rodando "pnpm run build" direto num
// Windows sem privilégio de symlink (sem admin, sem Developer Mode), a
// cópia falha com "EPERM: operation not permitted, symlink" mesmo com a
// compilação em si tendo funcionado. Por isso o standalone só liga quando o
// próprio Dockerfile pede explicitamente (NEXT_OUTPUT_STANDALONE=true) — a
// imagem Docker continua otimizada; build local (Windows, Linux ou Mac) usa
// o output padrão do Next, que nunca precisa de symlink. Ver
// DEPLOY-STANDARD.md#build-local-x-build-de-produção.
const isStandalone = process.env.NEXT_OUTPUT_STANDALONE === "true";

/** @type {import('next').NextConfig} */
const nextConfig = {
  ...(isStandalone ? { output: "standalone" } : {}),
  // O workspace root fica dois níveis acima de apps/web (raiz do monorepo).
  // Necessário para o output "standalone" localizar corretamente o
  // pnpm-lock.yaml e os pacotes do workspace ao rastrear dependências.
  outputFileTracingRoot: path.join(__dirname, "../../"),
  // packages/shared (e packages/api-client, quando existir) são consumidos
  // como TypeScript puro, sem build próprio — o webpack do Next transpila.
  transpilePackages: ["@{{PROJECT_SLUG}}/shared", "@{{PROJECT_SLUG}}/api-client"],
  eslint: {
    dirs: ["src"],
  },
  webpack: (config) => {
    // Os pacotes do workspace importam módulos internos com extensão ".js"
    // (convenção correta de ESM/TypeScript "moduleResolution: bundler") mesmo
    // apontando para arquivos ".ts". O webpack não resolve isso por padrão.
    config.resolve.extensionAlias = {
      ...(config.resolve.extensionAlias ?? {}),
      ".js": [".ts", ".tsx", ".js"],
    };
    return config;
  },
};

export default nextConfig;
