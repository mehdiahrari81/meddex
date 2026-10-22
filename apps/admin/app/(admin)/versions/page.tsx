import { api } from "@/lib/api";
import { DataTable, PageHeader } from "@/components/page";
export default async function VersionsPage() { return <><PageHeader title="Application and content versions" description="Stable content IDs, current revisions, and separately tracked published revisions." /><DataTable rows={await api<Record<string, unknown>[]>("/admin/content?limit=100")} /></>; }
