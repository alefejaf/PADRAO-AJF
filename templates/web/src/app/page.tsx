import Link from "next/link";
import { HelloForm } from "@/components/hello-form";

export default function HomePage() {
  return (
    <main>
      <h1>{{PROJECT_NAME}}</h1>
      <p>
        Aplicação gerada a partir do <code>PADRAO-AJF</code>. Veja a{" "}
        <Link href="/status">página de status</Link> ou o endpoint{" "}
        <code>/api/health</code>.
      </p>

      <h2>Exemplo de validação (Server Action + Zod)</h2>
      <HelloForm />
    </main>
  );
}
