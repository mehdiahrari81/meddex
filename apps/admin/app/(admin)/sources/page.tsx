import { api } from "@/lib/api";
import { DataTable, PageHeader } from "@/components/page";
export default async function SourcesPage() { return <><PageHeader title="Source details" description="Provider, jurisdiction, version, retrieval time, and fact counts. Provenance cannot be hidden." /><DataTable rows={await api<Record<string, unknown>[]>("/admin/sources")} /></>; }
