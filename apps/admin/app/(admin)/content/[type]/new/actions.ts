"use server";

import { revalidatePath } from "next/cache";
import { redirect, unstable_rethrow } from "next/navigation";
import { z } from "zod";
import { api } from "@/lib/api";

export type EditorState = { error?: string };
const schema = z.object({
  stableId: z.string().regex(/^[A-Za-z0-9._-]+$/).max(120),
  contentType: z.enum(["terminology", "morphology", "abbreviation", "lesson", "flashcard", "quiz", "translation", "dataset"]),
  content: z.string().min(2).max(4_500_000),
  sourceMetadata: z.string().min(2).max(20_000),
  reason: z.string().min(3).max(1000),
});

export async function createContent(_state: EditorState, formData: FormData): Promise<EditorState> {
  const parsed = schema.safeParse({
    stableId: formData.get("stableId"), contentType: formData.get("contentType"),
    content: formData.get("content"), sourceMetadata: formData.get("sourceMetadata"), reason: formData.get("reason"),
  });
  if (!parsed.success) return { error: "Complete the content fields and add a short change reason, then save again." };
  let content: Record<string, unknown>; let source: Record<string, unknown>;
  try { content = JSON.parse(parsed.data.content) as Record<string, unknown>; source = JSON.parse(parsed.data.sourceMetadata) as Record<string, unknown>; }
  catch { return { error: "The draft could not be read. Reload the page and try again." }; }
  if (!content || typeof content !== "object" || Array.isArray(content) || !source || typeof source !== "object" || Array.isArray(source)) {
    return { error: "The draft format is invalid. Reload the page and try again." };
  }
  try {
    await api("/admin/content", { method: "POST", body: JSON.stringify({ stable_id: parsed.data.stableId, content_type: parsed.data.contentType, content, source_metadata: source, change_reason: parsed.data.reason }) });
  } catch (error) { unstable_rethrow(error); return { error: error instanceof Error ? error.message : "Draft could not be saved." }; }
  revalidatePath(`/content/${parsed.data.contentType}`);
  redirect(`/content/${parsed.data.contentType}`);
}
