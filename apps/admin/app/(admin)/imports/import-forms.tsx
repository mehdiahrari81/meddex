"use client";

import { useActionState } from "react";
import { applyValidatedImport, validateImport, type ImportState } from "./actions";

function Feedback({ state }: { state: ImportState }) {
  return <>
    {state.error ? <p className="error" role="alert">{state.error}</p> : null}
    {state.success ? <p className="success" role="status">{state.success}</p> : null}
  </>;
}

export function ImportForms({ mode }: { mode: "validate" | "apply" }) {
  const [validation, validate, validating] = useActionState(validateImport, {});
  const [application, apply, applying] = useActionState(applyValidatedImport, {});
  if (mode === "apply") return <form action={apply} className="form">
    <Feedback state={application} />
    <label>Validated job ID<input name="jobId" required maxLength={36} /></label>
    <label>Repeat job ID to confirm<input name="confirmation" required maxLength={36} autoComplete="off" /></label>
    <button className="button danger" disabled={applying}>{applying ? "Applying import…" : "Apply reviewed import"}</button>
  </form>;
  return <form action={validate} className="form">
    <Feedback state={validation} />
    <label>Authoritative source name<input name="sourceName" required maxLength={300} /></label>
    <label>Source version<input name="sourceVersion" required maxLength={120} /></label>
    <label>CSV dataset<input name="file" type="file" accept=".csv,text/csv" aria-describedby="import-help" /></label>
    <p className="muted" id="import-help">Upload up to 5 MB and 10,000 records. Use registration ID, brand name, and ingredient or composition columns. Review the report before applying.</p>
    <details><summary>Use JSON records instead</summary>
      <label>JSON record array<textarea name="records" rows={10} maxLength={4_500_000} spellCheck={false} /></label>
    </details>
    <button disabled={validating}>{validating ? "Validating dataset…" : "Validate dataset"}</button>
  </form>;
}
