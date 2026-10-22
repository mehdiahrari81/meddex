import { api } from "@/lib/api";
import { DataTable, PageHeader } from "@/components/page";
import { ActionForm } from "@/components/action-form";
export default async function SessionsPage() { const rows = await api<Record<string, unknown>[]>("/admin/sessions"); return <><PageHeader title="Administrative sessions" description="Short-lived, inactivity-limited, revocable sessions. Tokens are never displayed." /><DataTable rows={rows} /><section className="card"><h2>Revoke session</h2><ActionForm kind="session"><label>Session ID<input name="sessionId" required /></label><label>Type session ID to confirm<input name="confirmation" required /></label><button className="button danger">Revoke access</button></ActionForm></section></>; }
