"use server";

import { buildGreeting } from "@/lib/greet";
import { logger } from "@/lib/logger";

export async function greetAction(_prevState: unknown, formData: FormData): Promise<{ message: string; error?: string }> {
  try {
    const name = formData.get("name");
    return buildGreeting({ name: typeof name === "string" && name.length > 0 ? name : undefined });
  } catch (error) {
    logger.warn("greetAction validation failed", { error: String(error) });
    return { message: "", error: "nome inválido" };
  }
}
