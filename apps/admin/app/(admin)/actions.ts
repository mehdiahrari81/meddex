"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { unstable_rethrow } from "next/navigation";
import { api, ApiError } from "@/lib/api";

const id = z.string().min(1).max(200);

export async function contentWorkflow(formData: FormData): Promise<void> {
  if (formData.get("confirmed") !== "yes") throw new ApiError(400, "Confirm the action for this record before continuing.");
  // Keep the API's exact-record confirmation contract while the UI uses a clear checkbox.
  formData.set("confirmation", String(formData.get("stableId") ?? ""));
  const parsed = z.object({ stableId: id, action: z.enum(["submit_review", "approve", "reject", "publish", "deprecate", "archive"]), reason: z.string().min(3).max(1000), confirmation: z.string().max(200) }).parse(Object.fromEntries(formData));
  await api(`/admin/content/${encodeURIComponent(parsed.stableId)}/workflow`, { method: "POST", body: JSON.stringify({ action: parsed.action, reason: parsed.reason, confirmation: parsed.confirmation || null }) });
  revalidatePath("/review");
  revalidatePath("/");
  revalidatePath("/content");
  revalidatePath("/content/[type]", "page");
  revalidatePath("/content/[type]/[id]", "page");
}

export type AdminActionKind = "content" | "flag" | "report" | "resolution" | "session";
export type AdminActionState = { error?: string; success?: string };

export async function performAdminAction(_state: AdminActionState, data: FormData): Promise<AdminActionState> {
  const kind = z.enum(["content", "flag", "report", "resolution", "session"]).safeParse(data.get("actionKind"));
  if (!kind.success) return { error: "Choose a supported action." };
  try {
    const handlers = { content: contentWorkflow, flag: updateFlag, report: reportWorkflow,
      resolution: annotateResolution, session: revokeSession };
    await handlers[kind.data](data);
    return { success: "The action was completed successfully." };
  } catch (error) {
    unstable_rethrow(error);
    return { error: error instanceof ApiError ? error.message : "Check the required fields and typed confirmation, then try again." };
  }
}

export async function updateFlag(formData: FormData): Promise<void> {
  const parsed = z.object({ key: id, enabled: z.enum(["true", "false"]), revision: z.coerce.number().int().positive(), confirmation: id }).parse(Object.fromEntries(formData));
  await api(`/admin/feature-flags/${encodeURIComponent(parsed.key)}`, { method: "PUT", body: JSON.stringify({ enabled: parsed.enabled === "true", expected_revision: parsed.revision, confirmation: parsed.confirmation }) });
  revalidatePath("/feature-flags");
}

export async function importDryRun(formData: FormData): Promise<void> {
  const parsed = z.object({ sourceName: z.string().min(1).max(300), sourceVersion: z.string().min(1).max(120), records: z.string().min(2).max(900_000) }).parse(Object.fromEntries(formData));
  const records = z.array(z.record(z.string(), z.unknown())).max(10_000).parse(JSON.parse(parsed.records));
  await api("/admin/imports/dry-run", { method: "POST", body: JSON.stringify({ dataset_type: "drap_products", source_name: parsed.sourceName, source_version: parsed.sourceVersion, records }) });
  revalidatePath("/imports");
}

export async function applyImport(formData: FormData): Promise<void> {
  const jobId = id.parse(formData.get("jobId"));
  const confirmation = id.parse(formData.get("confirmation"));
  await api(`/admin/imports/${encodeURIComponent(jobId)}/apply`, { method: "POST", body: JSON.stringify({ confirmation }) });
  revalidatePath("/imports");
}

export async function reportWorkflow(formData: FormData): Promise<void> {
  const parsed = z.object({ reportId: id, status: z.enum(["in_review", "resolved", "rejected"]), resolutionNote: z.string().min(3).max(2000), confirmation: id }).parse(Object.fromEntries(formData));
  await api(`/admin/reports/${encodeURIComponent(parsed.reportId)}/workflow`, { method: "POST", body: JSON.stringify({ status: parsed.status, resolution_note: parsed.resolutionNote, confirmation: parsed.confirmation }) });
  revalidatePath("/reports");
  revalidatePath("/");
}

export async function annotateResolution(formData: FormData): Promise<void> {
  const parsed = z.object({ resolutionId: id, note: z.string().min(3).max(1000), reviewStatus: z.enum(["needs_source", "reviewed_no_override", "candidate_investigation"]) }).parse(Object.fromEntries(formData));
  await api(`/admin/resolution-review/${encodeURIComponent(parsed.resolutionId)}/annotate`, { method: "POST", body: JSON.stringify({ note: parsed.note, review_status: parsed.reviewStatus }) });
  revalidatePath("/resolution-review");
}

export async function revokeSession(formData: FormData): Promise<void> {
  const sessionId = id.parse(formData.get("sessionId"));
  const confirmation = id.parse(formData.get("confirmation"));
  if (sessionId !== confirmation) throw new Error("Typed confirmation does not match.");
  await api(`/admin/sessions/${encodeURIComponent(sessionId)}/revoke`, { method: "POST" });
  revalidatePath("/sessions");
}
