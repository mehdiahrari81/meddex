"use client";

import { useActionState, useState } from "react";
import { performAdminAction, type AdminActionState } from "@/app/(admin)/actions";

export function ContentWorkflowForm({ stableId, actions }: { stableId: string; actions: { value: string; label: string }[] }) {
  const [state, submit, pending] = useActionState(performAdminAction, {} as AdminActionState);
  const [selected, setSelected] = useState(actions[0].value);
  const [confirmed, setConfirmed] = useState(false);
  const action = actions.find(item => item.value === selected) ?? actions[0];
  return <form action={submit} className="form" aria-busy={pending}>
    <input type="hidden" name="actionKind" value="content" />
    <input type="hidden" name="stableId" value={stableId} />
    {state.error ? <p className="error" role="alert">{state.error}</p> : null}
    {state.success ? <p className="success" role="status">{state.success}</p> : null}
    <fieldset disabled={pending}>
      <label>Action<select name="action" aria-label="Action" value={selected} onChange={event => { setSelected(event.target.value); setConfirmed(false); }}>{actions.map(item => <option value={item.value} key={item.value}>{item.label}</option>)}</select></label>
      <label>Reason<textarea name="reason" minLength={3} maxLength={1000} placeholder="Briefly describe your review or decision" required /></label>
      <label className="editor-check"><input type="checkbox" name="confirmed" value="yes" checked={confirmed} onChange={event => setConfirmed(event.target.checked)} required />I confirm this action for this record</label>
      <button disabled={pending || !confirmed}>{pending ? "Saving…" : action.label}</button>
    </fieldset>
  </form>;
}
