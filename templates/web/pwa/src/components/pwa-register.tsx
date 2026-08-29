"use client";

import { useEffect } from "react";
import { registerServiceWorker } from "@/lib/register-service-worker";

export function PwaRegister() {
  useEffect(() => {
    registerServiceWorker();
  }, []);

  return null;
}
