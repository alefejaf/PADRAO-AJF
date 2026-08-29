# {{PROJECT_SLUG}}-mobile

Aplicativo mobile de {{PROJECT_NAME}}, construído com [Expo](https://expo.dev) (React Native) + TypeScript.

O app **nunca** acessa o PostgreSQL diretamente. Fluxo obrigatório:

```
Mobile → HTTPS → API → Banco
```

## Estrutura

```
mobile/
├── App.tsx
├── index.ts
├── app.json
└── src/
    ├── screens/HomeScreen.tsx   # tela inicial, mostra o status da API
    └── lib/
        ├── config.ts            # leitura de EXPO_PUBLIC_API_URL
        └── api-client.ts        # cliente HTTP centralizado (fetch + tratamento de erro)
```

## Desenvolvimento

```bash
cp .env.example .env
pnpm install
pnpm --filter {{PROJECT_SLUG}}-mobile run start
```

Abra no Expo Go (celular) ou em um emulador Android/iOS a partir do terminal interativo do Expo.

## Scripts

| Script | Descrição |
|---|---|
| `pnpm run start` | Sobe o servidor de desenvolvimento Expo. |
| `pnpm run android` / `run ios` / `run web` | Atalhos para abrir em uma plataforma específica. |
| `pnpm run typecheck` | Verifica os tipos TypeScript. |
| `pnpm run test` | Executa os testes de lógica pura (Vitest). |

## Build (EAS) — não passa pelo GHCR

Aplicativos mobile **não** são publicados como imagem Docker/GHCR. O build e a distribuição
usam o [EAS Build](https://docs.expo.dev/build/introduction/) da própria Expo:

```bash
npm install -g eas-cli
eas login
eas build:configure
eas build --platform android --profile production
eas build --platform ios --profile production
```

Publicação nas lojas:

```bash
eas submit --platform android
eas submit --platform ios
```

Documente credenciais de assinatura (keystore/certificados) apenas em cofres de segredo
(1Password, Bitwarden, GitHub Encrypted Secrets) — nunca neste repositório.

## Variáveis de ambiente

Apenas variáveis prefixadas com `EXPO_PUBLIC_` chegam ao bundle do app (ficam visíveis a
quem instalar o app). Nunca coloque segredos nelas — segredos ficam só no backend (API).

**`EXPO_PUBLIC_API_URL` em produção precisa ser a URL pública HTTPS da API.** Nunca
`localhost` (só existe no dispositivo/emulador de quem fez o build) e nunca um hostname
interno do Docker como `http://api:3001` (só resolve dentro da rede do docker-compose — o
celular do usuário nunca vai conseguir alcançar isso). Configure o valor de produção antes de
rodar `eas build`.
