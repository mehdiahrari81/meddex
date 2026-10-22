import { api } from "@/lib/api";
import { DataTable, PageHeader } from "@/components/page";
export default async function HealthPage() { const value = await api<Record<string, unknown>>("/admin/system-health"); return <><PageHeader title="System health" description="Readiness and operational data measured by the backend at request time." /><DataTable rows={[value]} /></>; }
