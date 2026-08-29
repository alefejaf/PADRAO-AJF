# @{{PROJECT_SLUG}}/api-client

Cliente HTTP tipado para `apps/api`, usado por `apps/web` e/ou `apps/mobile`.
Só é gerado quando o projeto tem API separada.

## Uso

```ts
import { createApiClient } from "@{{PROJECT_SLUG}}/api-client";

const api = createApiClient({ baseUrl: process.env.NEXT_PUBLIC_API_URL! });
const health = await api.getHealth();
```

Toda resposta é validada em runtime com os mesmos schemas Zod usados pela API
(`@{{PROJECT_SLUG}}/shared`), então um payload inesperado nunca chega "cru" à UI.
