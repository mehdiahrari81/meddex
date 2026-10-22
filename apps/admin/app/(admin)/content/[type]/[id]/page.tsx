import Link from "next/link";
import { notFound } from "next/navigation";
import { ContentWorkflowForm } from "@/components/content-workflow-form";
import { PageHeader, Value } from "@/components/page";
import { ContentPreview } from "@/components/content-preview";
import { api, ApiError, currentAdmin } from "@/lib/api";
import { contentTypes, type ContentRecord, type ContentRevision, type ReferenceOptions } from "@/lib/content";

export default async function ContentDetail({ params }: { params: Promise<{ type: string; id: string }> }) {
  const { type, id } = await params;
  if (!contentTypes.has(type)) notFound();
  const admin = await currentAdmin();
  const path = `/admin/content/${encodeURIComponent(id)}`;
  let record: ContentRecord;
  let revisions: ContentRevision[];
  let options: ReferenceOptions;
  try {
    [record, revisions, options] = await Promise.all([api<ContentRecord>(path), api<ContentRevision[]>(`${path}/revisions?limit=50`), api<ReferenceOptions>("/admin/reference/options")]);
  } catch (error) {
    if (error instanceof ApiError && error.status === 404) notFound();
    throw error;
  }
  if (record.content_type !== type) notFound();
  const permission = new Set(admin.permissions);
  const latest = revisions[0];
  const actions: { value: string; label: string }[] = [];
  if (record.lifecycle_state === "draft" && permission.has("content.edit")) actions.push({ value: "submit_review", label: "Submit for review" });
  if (record.lifecycle_state === "in_review" && permission.has("content.review")) {
    if (latest?.author_id !== admin.user_id || admin.local_self_review_allowed) actions.push({ value: "approve", label: latest?.author_id === admin.user_id ? "Approve for local development" : "Approve revision" });
    actions.push({ value: "reject", label: "Return to draft" });
  }
  if (permission.has("content.publish")) {
    if (record.lifecycle_state === "approved") actions.push({ value: "publish", label: "Publish revision" });
    if (record.lifecycle_state === "published" && type !== "dataset") actions.push({ value: "deprecate", label: "Deprecate content" });
    if (record.lifecycle_state === "deprecated") actions.push({ value: "archive", label: "Archive content" });
  }
  return <>
    <PageHeader title={String(latest?.content.title || latest?.content.term || latest?.content.value || latest?.content.abbreviation || latest?.content.prompt || latest?.content.front || id)} description={`Current revision ${record.current_revision} · ${record.lifecycle_state}. Published revision: ${record.published_revision ?? "None"}. Record: ${id}`} actions={permission.has("content.edit") && id !== "reference.mobile" ? <Link className="button" href={`/content/${type}/new?id=${encodeURIComponent(id)}`}>Create revised draft</Link> : undefined} />
    {admin.local_self_review_allowed ? <p className="muted">Local development permits audited single-admin review. Production requires an independent reviewer.</p> : null}
    {actions.length ? <section className="card"><h2>Review action</h2><ContentWorkflowForm key={`${record.current_revision}-${record.lifecycle_state}`} stableId={id} actions={actions} /></section> : <p className="muted">No workflow action is currently available for this record and your role.</p>}
    {revisions.map((revision) => <section className="card" key={revision.revision}>
      <h2>Revision {revision.revision} · {revision.review_state}</h2>
      <p>{revision.change_reason}</p>
      <p className="muted">Created <Value value={revision.created_at} /> · Author {revision.author_id}</p>
      {revision.reviewed_at ? <p className="muted">Reviewed <Value value={revision.reviewed_at} /> · Reviewer {revision.reviewer_id}</p> : null}
      {revision.published_at ? <p className="muted">Published <Value value={revision.published_at} /></p> : null}
      <h3>Content</h3><ContentPreview content={revision.content} options={options} />
      <h3>Source attribution</h3>
      {revision.source_metadata.provider ? <p>{String(revision.source_metadata.provider)}</p> : null}
      {revision.source_metadata.uploaded_filename ? <p>File: {String(revision.source_metadata.uploaded_filename)}</p> : null}
      {revision.source_metadata.note ? <p>{String(revision.source_metadata.note)}</p> : null}
      <details><summary>Technical record details</summary><p>Source metadata</p><pre className="code">{JSON.stringify(revision.source_metadata, null, 2)}</pre><p>Stored content</p><pre className="code">{JSON.stringify(revision.content, null, 2)}</pre></details>
    </section>)}
    <Link href={`/content/${type}`}>Back to {type} management</Link>
  </>;
}
