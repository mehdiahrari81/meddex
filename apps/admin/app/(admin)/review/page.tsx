import { api } from "@/lib/api";
import { DataTable, PageHeader } from "@/components/page";
export default async function ReviewPage() {
  const rows: Record<string, unknown>[] = [];
  for (let offset = 0; ; offset += 100) {
    const page = await api<Record<string, unknown>[]>(`/admin/content?limit=100&offset=${offset}`);
    rows.push(...page.filter(item => item.lifecycle_state === "in_review"));
    if (page.length < 100) break;
  }
  return <><PageHeader title="Content review queue" description="Open a record by its title to read the content, review it, and choose an available action. Publishing is a separate confirmed step." /><DataTable rows={rows} /></>;
}
