"use client";

import { useActionState, type ReactNode } from "react";
import { performAdminAction, type AdminActionKind } from "@/app/(admin)/actions";

export function ActionForm({ kind, children }: { kind: AdminActionKind; children: ReactNode }) {
  const [state, action, pending] = useActionState(performAdminAction, {});
  return <form action={action} className="form" aria-busy={pending}>
    <input type="hidden" name="actionKind" value={kind} />
    {state.error ? <p className="error" role="alert">{state.error}</p> : null}
    {state.success ? <p className="success" role="status">{state.success}</p> : null}
    <fieldset disabled={pending}>{children}</fieldset>
    {pending ? <p className="muted" role="status">Saving changes…</p> : null}
  </form>;
}
