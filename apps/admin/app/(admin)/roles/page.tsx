import { api } from "@/lib/api";
import { DataTable, PageHeader } from "@/components/page";
export default async function RolesPage() { return <><PageHeader title="Roles and permissions" description="Backend-enforced permissions; role labels do not imply medical credentials." /><DataTable rows={await api<Record<string, unknown>[]>("/admin/roles")} /></>; }
