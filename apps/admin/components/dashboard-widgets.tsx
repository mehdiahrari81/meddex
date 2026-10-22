"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import { friendly, shortDate, type RecentContent } from "@/lib/dashboard";
import { Icon } from "./icon";

export function RefreshDashboard() {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  return (
    <button
      className="button secondary"
      disabled={pending}
      onClick={() => startTransition(() => router.refresh())}
    >
      <Icon name="refresh" size={16} className={pending ? "spin" : undefined} />
      {pending ? "Refreshing…" : "Refresh"}
    </button>
  );
}

export function ActivityPeriod({ days }: { days: number }) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  return (
    <select
      className="period-select"
      aria-label="Activity period"
      value={days}
      disabled={pending}
      onChange={(event) =>
        startTransition(() =>
          router.replace(`/?days=${event.target.value}`, { scroll: false }),
        )
      }
    >
      <option value={7}>Last 7 days</option>
      <option value={14}>Last 14 days</option>
      <option value={30}>Last 30 days</option>
    </select>
  );
}

export function RecentContentTable({ rows }: { rows: RecentContent[] }) {
  const [filter, setFilter] = useState("all");
  const visible = rows.filter(
    (row) => filter === "all" || row.state === filter,
  );
  return (
    <>
      <div className="content-tabs" aria-label="Filter recent content">
        {[
          ["all", "All records"],
          ["in_review", "In review"],
          ["draft", "Drafts"],
          ["approved", "Approved"],
        ].map(([value, label]) => (
          <button
            key={value}
            className={filter === value ? "selected" : ""}
            aria-pressed={filter === value}
            onClick={() => setFilter(value)}
          >
            {label}
          </button>
        ))}
      </div>
      <div className="table-scroll">
        <table className="content-table">
          <thead>
            <tr>
              <th scope="col">Content</th>
              <th scope="col">Status</th>
              <th scope="col">Updated</th>
              <th scope="col">
                <span className="sr-only">Open record</span>
              </th>
            </tr>
          </thead>
          <tbody>
            {visible.slice(0, 6).map((row) => (
              <tr key={row.stable_id}>
                <td>
                  <Link
                    className="content-title"
                    href={`/content/${row.content_type}/${row.stable_id}`}
                  >
                    {row.title}
                  </Link>
                  <span className="content-meta">
                    {friendly(row.content_type)} <span>·</span> v{row.revision}
                    {row.is_demo && <span className="demo-tag">Demo</span>}
                  </span>
                </td>
                <td>
                  <span className={`status status-${row.state}`}>
                    <i />
                    {friendly(row.state)}
                  </span>
                </td>
                <td>
                  <time dateTime={row.updated_at}>
                    {shortDate(row.updated_at)}
                  </time>
                </td>
                <td>
                  <Link
                    className="row-arrow"
                    aria-label={`Open ${row.title}`}
                    href={`/content/${row.content_type}/${row.stable_id}`}
                  >
                    <Icon name="arrow" size={17} />
                  </Link>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {!visible.length && (
          <div className="compact-empty">
            <Icon name="inbox" size={28} />
            <p>No recent records in this view.</p>
          </div>
        )}
      </div>
      <div className="panel-footer">
        <span>
          Showing {Math.min(visible.length, 6)} of {rows.length} most recent
          records
        </span>
        <Link href="/content/terminology">
          Browse library <Icon name="arrow" size={14} />
        </Link>
      </div>
    </>
  );
}
