# @{{PROJECT_SLUG}}/shared

Código compartilhado entre `apps/web`, `apps/api` e `apps/mobile`.

## Contém

- `src/types` — tipos TypeScript reutilizáveis.
- `src/schemas` — schemas Zod (fonte única de validação, usados no client e no server).
- `src/constants` — constantes (rotas, portas padrão, papéis de usuário).

## Regras

- Não colocar aqui código específico de frontend (React, DOM, etc).
- Não colocar aqui código que dependa de Node.js (fs, path, etc) — precisa rodar tanto em mobile quanto em browser quanto em server.
- Toda regra de validação de entrada/saída de API deve nascer aqui, não duplicada em cada app.

## Uso

Este pacote é consumido como código-fonte TypeScript (sem build), via workspace do pnpm:

```json
{
  "dependencies": {
    "@{{PROJECT_SLUG}}/shared": "workspace:*"
  }
}
```
