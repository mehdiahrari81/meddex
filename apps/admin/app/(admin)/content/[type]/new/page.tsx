import { notFound, redirect } from "next/navigation";
import { PageHeader } from "@/components/page";
import { api, currentAdmin } from "@/lib/api";
import { contentTypes, type ContentRecord, type ContentRevision, type ReferenceOptions } from "@/lib/content";
import { Editor } from "./editor";

export default async function NewContentPage({ params, searchParams }: {
  params: Promise<{ type: string }>;
  searchParams: Promise<{ id?: string }>;
}) {
  const { type } = await params;
  const { id } = await searchParams;
  if (!contentTypes.has(type)) notFound();
  const admin = await currentAdmin();
  if (!admin.permissions.includes("content.edit")) redirect(`/content/${type}`);
  let revision: ContentRevision | undefined;
  if (id) {
    const path = `/admin/content/${encodeURIComponent(id)}`;
    const record = await api<ContentRecord>(path);
    if (record.content_type !== type) notFound();
    revision = (await api<ContentRevision[]>(`${path}/revisions?limit=1`))[0];
  }
  const options = await api<ReferenceOptions>("/admin/reference/options");
  const label = ({ terminology: "medical term", morphology: "word part", abbreviation: "abbreviation", lesson: "lesson", flashcard: "flashcard", quiz: "quiz question", translation: "translation", dataset: "reference release" } as Record<string, string>)[type];
  return <><PageHeader title={id ? `Edit ${label}` : `Add ${label}`} description="Enter your content, choose its reference, and save. No code or technical formatting is needed." /><section className="card"><Editor type={type} options={options} stableId={id} content={revision?.content} source={revision?.source_metadata} /></section></>;
}
