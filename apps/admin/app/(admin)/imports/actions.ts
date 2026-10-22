"use server";

import { revalidatePath } from "next/cache";
import { unstable_rethrow } from "next/navigation";
import { z } from "zod";
import { api, ApiError } from "@/lib/api";

export type ImportState = { error?: string; success?: string };

export async function validateImport(_state: ImportState, data: FormData): Promise<ImportState> {
  try {
    const source = z.object({
      sourceName: z.string().trim().min(1).max(300),
      sourceVersion: z.string().trim().min(1).max(120),
    }).parse(Object.fromEntries(data));
    const file = data.get("file");
    let job: { id: string; status: string };
    if (file instanceof File && file.size > 0) {
      if (file.size > 5_000_000) return { error: "Choose a CSV file smaller than 5 MB." };
      const upload = new FormData();
      upload.set("file", file);
      upload.set("source_name", source.sourceName);
      upload.set("source_version", source.sourceVersion);
      job = await api("/admin/imports/drap/upload", { method: "POST", body: upload });
    } else {
      const records = z.array(z.record(z.string(), z.unknown())).min(1).max(10_000).parse(
        JSON.parse(z.string().min(2).max(4_500_000).parse(data.get("records"))),
      );
      job = await api("/admin/imports/dry-run", {
        method: "POST",
        body: JSON.stringify({
          dataset_type: "drap_products", source_name: source.sourceName,
          source_version: source.sourceVersion, records,
        }),
      });
    }
    revalidatePath("/imports");
    return job.status === "validated"
      ? { success: `Validation passed. Review job ${job.id} below before applying it.` }
      : { error: `Validation found rejected records. Review the report for job ${job.id}.` };
  } catch (error) {
    unstable_rethrow(error);
    return { error: error instanceof ApiError ? error.message : "Enter a source name and version, and supply a valid CSV or JSON record array." };
  }
}

export async function applyValidatedImport(_state: ImportState, data: FormData): Promise<ImportState> {
  const parsed = z.object({ jobId: z.uuid(), confirmation: z.uuid() }).safeParse(Object.fromEntries(data));
  if (!parsed.success || parsed.data.jobId !== parsed.data.confirmation) {
    return { error: "Enter a valid job ID and repeat it exactly to confirm." };
  }
  try {
    await api(`/admin/imports/${parsed.data.jobId}/apply`, {
      method: "POST", body: JSON.stringify({ confirmation: parsed.data.confirmation }),
    });
    revalidatePath("/imports");
    return { success: `Import ${parsed.data.jobId} applied successfully.` };
  } catch (error) {
    unstable_rethrow(error);
    return { error: error instanceof ApiError ? error.message : "The import could not be applied. Review its validation report and try again." };
  }
}
