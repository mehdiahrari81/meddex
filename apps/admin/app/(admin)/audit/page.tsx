import { api } from "@/lib/api";
import { DataTable, PageHeader } from "@/components/page";
export default async function AuditPage() { return <><PageHeader title="Audit logs" description="Append-oriented sensitive-action records with actor, permission context, target, time, and request ID." /><DataTable rows={await api<Record<string, unknown>[]>("/admin/audit?limit=100")} /></>; }
