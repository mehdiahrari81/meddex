import Link from "next/link";
import { api, currentAdmin } from "@/lib/api";
import { contentTypes } from "@/lib/content";
import { notFound } from "next/navigation";
import { DataTable, PageHeader } from "@/components/page";

export default async function ContentPage({ params }: { params: Promise<{ type: string }> }) {
  const { type } = await params;
  if (!contentTypes.has(type)) notFound();
  const admin = await currentAdmin();
  const filtered: Record<string, unknown>[] = [];
  for (let offset = 0; ; offset += 100) {
    const rows = await api<Record<string, unknown>[]>(`/admin/content?content_type=${encodeURIComponent(type)}&limit=100&offset=${offset}`);
    filtered.push(...rows);
    if (rows.length < 100) break;
  }
  const label = ({ terminology: "medical term", morphology: "word part", abbreviation: "abbreviation", lesson: "lesson", flashcard: "flashcard", quiz: "quiz question", translation: "translation", dataset: "reference release" } as Record<string, string>)[type];
  return <><PageHeader title={`${type[0]?.toUpperCase()}${type.slice(1)} management`} description="Add content using a simple form, or open an existing record by its title to edit and review it." actions={admin.permissions.includes("content.edit") ? <Link className="button" href={`/content/${type}/new`}>Add {label}</Link> : undefined} /><DataTable rows={filtered} /></>;
}
