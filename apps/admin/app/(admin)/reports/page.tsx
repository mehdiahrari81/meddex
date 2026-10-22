import { api } from "@/lib/api";
import { DataTable, PageHeader } from "@/components/page";
import { ActionForm } from "@/components/action-form";
import Link from "next/link";

export default async function ReportsPage({
  searchParams,
}: {
  searchParams: Promise<{ type?: string; report?: string }>;
}) {
  const { type, report } = await searchParams;
  const rows = await api<Record<string, unknown>[]>("/admin/reports?limit=100");
  const selected = rows.find((item) => item.id === report);
  const filtered = selected
    ? [selected]
    : type
      ? rows.filter((item) => item.report_type === type)
      : rows;
  return (
    <>
      <PageHeader
        title={type === "unsafe_ai" ? "AI safety reports" : "Content reports"}
        description="Review redacted context, document a decision, and record an audited resolution."
        actions={
          selected ? (
            <Link className="button secondary" href="/reports">
              All reports
            </Link>
          ) : undefined
        }
      />
      <DataTable rows={filtered} />
      <section className="card">
        <h2>Resolve a report</h2>
        <p className="muted">
          A resolution note and matching report ID are required to apply a
          change.
        </p>
        <ActionForm key={String(selected?.id ?? "all")} kind="report">
          <label>
            Report ID
            <input
              name="reportId"
              defaultValue={String(selected?.id ?? "")}
              required
            />
          </label>
          <label>
            Status
            <select name="status">
              <option value="in_review">In review</option>
              <option value="resolved">Resolved</option>
              <option value="rejected">Rejected</option>
            </select>
          </label>
          <label>
            Resolution note
            <textarea name="resolutionNote" required />
          </label>
          <label>
            Type report ID to confirm
            <input name="confirmation" required />
          </label>
          <button className="button">Apply audited resolution</button>
        </ActionForm>
      </section>
    </>
  );
}
