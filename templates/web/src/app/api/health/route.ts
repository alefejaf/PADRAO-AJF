import { healthResponseSchema } from "@{{PROJECT_SLUG}}/shared";
import { NextResponse } from "next/server";

export const dynamic = "force-dynamic";

export async function GET() {
  const payload = healthResponseSchema.parse({
    status: "ok",
    service: "{{PROJECT_SLUG}}-web",
    version: process.env.APP_VERSION ?? "0.0.0",
    timestamp: new Date().toISOString(),
  });

  return NextResponse.json(payload);
}
