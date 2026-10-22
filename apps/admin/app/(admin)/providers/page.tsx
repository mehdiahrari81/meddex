import { api } from "@/lib/api";
import { DataTable, PageHeader } from "@/components/page";
export default async function ProvidersPage() { return <><PageHeader title="Medical provider status" description="Observed request success, latency, cache behavior, and latest activity from recorded provider calls." /><DataTable rows={await api<Record<string, unknown>[]>("/admin/provider-health")} /></>; }
