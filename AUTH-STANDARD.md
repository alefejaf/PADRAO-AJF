# AUTH-STANDARD.md

## Autenticação x autorização

- **Authentication (quem é o usuário)** — confirmar identidade: login, sessão, token.
- **Authorization (o que ele pode fazer)** — decidir se essa identidade pode executar essa ação.

São dois problemas diferentes e os dois precisam existir — autenticar sem autorizar só
confirma quem bateu na porta, não o que essa pessoa pode fazer depois de entrar.

## A autenticação é modular

O PADRAO-AJF **não força um único fornecedor**. Escolha o que fizer sentido para o projeto:

- **Supabase Auth** — quando o banco já é Supabase.
- **Auth.js** (NextAuth) — quando o projeto é Next.js e quer controle total sobre providers.
- Outra solução compatível com o ecossistema Node/TypeScript, desde que documentada aqui.

O que **não muda** entre soluções é o modelo de papéis e a regra de nunca confiar só no
frontend (abaixo).

## Papéis (roles)

Padrão mínimo, extensível por projeto:

```
USER      # usuário comum
MANAGER   # gestão de uma área/equipe
ADMIN     # administração completa
```

Extensão é normal (`FINANCE`, `SUPPORT`, etc.) — o importante é que todo papel novo seja
verificado no backend, não só usado para decidir o que renderizar na tela.

## Regra inegociável: nunca confiar só no frontend

**Errado:**

```tsx
{user.role === "ADMIN" && <BotaoAdmin />}
```

...e a rota/endpoint por trás do botão não verifica nada. Qualquer pessoa com DevTools aberto
ou chamando a API diretamente contorna isso.

**Correto:**

```tsx
{user.role === "ADMIN" && <BotaoAdmin />}
```

**+ no backend**, toda rota/Server Action que o botão chama valida a sessão e o papel:

```ts
// apps/api/src/routes/... (ou Server Action / Route Handler no Next.js)
if (session.user.role !== "ADMIN") {
  return reply.status(403).send({ error: { code: "FORBIDDEN", message: "forbidden" } });
}
```

Esconder o botão é UX. **Validar no backend é segurança.** Um sem o outro não é autorização —
é só uma sugestão visual.

## Onde a verificação acontece

```
Web/Mobile → chamada HTTP → API (ou Route Handler/Server Action) → verifica sessão + papel → executa ou nega
```

Nunca:

```
Web/Mobile → decide sozinho no cliente → confia no que o próprio cliente decidiu
```

## Segredos de autenticação

- `AUTH_SECRET` / chaves de assinatura de sessão: variável de ambiente, nunca no código.
- Tokens de sessão e refresh tokens: nunca logados (ver [`SECURITY-STANDARD.md`](./SECURITY-STANDARD.md)).
- Cookies de sessão: `HttpOnly`, `Secure` em produção, `SameSite` apropriado.

## Ver também

- [`SECURITY-STANDARD.md`](./SECURITY-STANDARD.md)
- [`DATABASE-STANDARD.md`](./DATABASE-STANDARD.md#supabase) — Supabase Auth especificamente.
