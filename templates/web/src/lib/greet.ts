import { exampleQuerySchema } from "@{{PROJECT_SLUG}}/shared";

/**
 * Pure validation + business logic, kept separate from the Server Action so it
 * can be unit tested without spinning up Next.js.
 */
export function buildGreeting(input: unknown): { message: string } {
  const { name } = exampleQuerySchema.parse(input);
  return { message: `hello, ${name ?? "world"}!` };
}
