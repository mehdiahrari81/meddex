export type DashboardSnapshot = {
  checked_at: string;
  environment: string;
  days: number;
  demo_records: number;
  content: {
    total: number;
    states: Record<string, number>;
    types: { type: string; count: number }[];
  } | null;
  reports: { total: number; states: Record<string, number> } | null;
  recent_content: RecentContent[];
  recent_reports: {
    id: string;
    reason: string;
    type: string;
    target_id: string;
    summary: string;
    status: string;
    created_at: string;
    is_demo: boolean;
  }[];
  recent_activity: {
    id: string;
    action: string;
    target_id: string;
    target_type: string;
    occurred_at: string;
    is_demo: boolean;
  }[];
  editorial_activity: { date: string; count: number }[];
};
export type RecentContent = {
  stable_id: string;
  title: string;
  content_type: string;
  state: string;
  revision: number;
  updated_at: string;
  is_demo: boolean;
};
export const friendly = (value: string) =>
  value.replaceAll("_", " ").replaceAll(".", " ");
export const shortDate = (value: string) =>
  new Intl.DateTimeFormat("en", {
    month: "short",
    day: "numeric",
    timeZone: "UTC",
  }).format(new Date(value));
