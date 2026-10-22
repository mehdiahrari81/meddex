import { api } from "@/lib/api";
import { DataTable, PageHeader } from "@/components/page";
export default async function UsersPage() { return <><PageHeader title="User support" description="Minimum account metadata only. Prescription images, medical history, tokens, and AI bodies are excluded." /><DataTable rows={await api<Record<string, unknown>[]>("/admin/user-support")} /></>; }
