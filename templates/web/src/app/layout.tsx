import type { Metadata } from "next";
import "./globals.css";
{{PWA_REGISTER_IMPORT}}

export const metadata: Metadata = {
  title: "{{PROJECT_NAME}}",
  description: "{{PROJECT_NAME}} — gerado a partir do PADRAO-AJF.",
  {{PWA_MANIFEST_FIELD}}
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="pt-BR">
      <body>
        {children}
        {{PWA_REGISTER_COMPONENT}}
      </body>
    </html>
  );
}
