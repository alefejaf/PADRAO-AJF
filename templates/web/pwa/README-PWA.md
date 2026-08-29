# PWA

Este projeto foi gerado com suporte a PWA (`-Pwa`). Foram adicionados:

- `public/manifest.json` — nome, ícones e cores do app instalável.
- `public/icons/icon-192.png` e `icon-512.png` — ícones placeholder (substitua pelos ícones reais).
- `public/sw.js` — service worker com estratégia **network-first** (nunca cache-first), para
  evitar que usuários fiquem presos numa versão antiga do sistema.
- `src/lib/register-service-worker.ts` + `src/components/pwa-register.tsx` — registro do
  service worker, ativo apenas em produção (`NODE_ENV=production`).

## Por que network-first?

Caching agressivo (cache-first) é a causa mais comum de "meu app não atualiza depois do
deploy". Por padrão este template busca sempre a rede primeiro e só usa o cache como
fallback quando o dispositivo está offline.

Este arquivo (`README-PWA.md`) pode ser apagado após a leitura — é apenas documentação
gerada pelo PADRAO-AJF, não faz parte da aplicação.
