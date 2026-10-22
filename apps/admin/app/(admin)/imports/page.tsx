import { api } from "@/lib/api";
import { DataTable, PageHeader } from "@/components/page";
import { ImportForms } from "./import-forms";

export default async function ImportsPage() {
  const rows = await api<Record<string, unknown>[]>("/admin/imports?limit=100");
  return <>
    <PageHeader title="Import jobs" description="Validate source data, review the report, then apply an approved dataset." />
    <section className="card"><h2>Validate DRAP dataset</h2><ImportForms mode="validate" /></section>
    <DataTable rows={rows} />
    <section className="card"><h2>Apply validated job</h2><ImportForms mode="apply" /></section>
  </>;
}
