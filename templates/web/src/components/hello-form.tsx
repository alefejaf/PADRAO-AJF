"use client";

import { useActionState } from "react";
import { greetAction } from "@/app/actions";

const initialState = { message: "", error: undefined as string | undefined };

export function HelloForm() {
  const [state, formAction, pending] = useActionState(greetAction, initialState);

  return (
    <form action={formAction} style={{ display: "flex", gap: 8, alignItems: "center" }}>
      <label htmlFor="name">Seu nome:</label>
      <input id="name" name="name" placeholder="Ada" maxLength={60} />
      <button type="submit" disabled={pending}>
        {pending ? "Enviando..." : "Enviar"}
      </button>
      {state.message ? <span role="status">{state.message}</span> : null}
      {state.error ? <span role="alert">{state.error}</span> : null}
    </form>
  );
}
