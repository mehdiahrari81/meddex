"use client";

import Link from "next/link";
import { useId, useState } from "react";
import { Icon } from "./icon";
import { Value } from "./value";

export function DataTable({ rows }: { rows: Record<string, unknown>[] }) {
  const [query, setQuery] = useState("");
  const [status, setStatus] = useState("");
  const [page, setPage] = useState(0);
  const [sort, setSort] = useState<{
    column: string;
    direction: number;
  } | null>(null);
  const searchId = useId();
  if (!rows.length)
    return (
      <section className="card empty">
        <Icon name="inbox" size={32} />
        <h2>No records yet</h2>
        <p>Records will appear here when they are added to this workspace.</p>
      </section>
    );
  const columns = Object.keys(rows[0]);
  const stateKey = ["lifecycle_state", "status", "state"].find((key) =>
    columns.includes(key),
  );
  const states = stateKey
    ? [...new Set(rows.map((row) => String(row[stateKey])))].sort()
    : [];
  const filtered = rows.filter(
    (row) =>
      JSON.stringify(row).toLowerCase().includes(query.trim().toLowerCase()) &&
      (!status || row[stateKey!] === status),
  );
  const ordered = sort
    ? [...filtered].sort((a, b) => {
        const left = a[sort.column];
        const right = b[sort.column];
        return (
          sort.direction *
          (typeof left === "number" && typeof right === "number"
            ? left - right
            : String(left ?? "").localeCompare(String(right ?? ""), "en", {
                numeric: true,
              }))
        );
      })
    : filtered;
  const lastPage = Math.max(0, Math.ceil(ordered.length / 10) - 1);
  const currentPage = Math.min(page, lastPage);
  const visible = ordered.slice(currentPage * 10, currentPage * 10 + 10);
  return (
    <section className="records-panel">
      <div className="table-toolbar">
        <label className="table-search" htmlFor={searchId}>
          <Icon name="search" size={17} />
          <span className="sr-only">Search records</span>
          <input
            id={searchId}
            type="search"
            placeholder="Search these records…"
            value={query}
            onChange={(event) => {
              setQuery(event.target.value);
              setPage(0);
            }}
          />
        </label>
        {states.length > 1 && (
          <select
            aria-label="Filter records by status"
            value={status}
            onChange={(event) => {
              setStatus(event.target.value);
              setPage(0);
            }}
          >
            <option value="">All statuses</option>
            {states.map((state) => (
              <option value={state} key={state}>
                {state.replaceAll("_", " ")}
              </option>
            ))}
          </select>
        )}
        <span className="record-count" aria-live="polite">
          {filtered.length} {filtered.length === 1 ? "record" : "records"}
        </span>
      </div>
      <div className="table-scroll">
        <table>
          <thead>
            <tr>
              {columns.map((column) => (
                <th
                  scope="col"
                  key={column}
                  aria-sort={
                    sort?.column === column
                      ? sort.direction > 0
                        ? "ascending"
                        : "descending"
                      : "none"
                  }
                >
                  <button
                    className="column-sort"
                    onClick={() => {
                      setSort({
                        column,
                        direction:
                          sort?.column === column ? -sort.direction : 1,
                      });
                      setPage(0);
                    }}
                  >
                    {column.replaceAll("_", " ")}
                    <span aria-hidden="true">
                      {sort?.column === column
                        ? sort.direction > 0
                          ? "↑"
                          : "↓"
                        : "↕"}
                    </span>
                  </button>
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {visible.map((row, index) => (
              <tr key={String(row.id ?? row.stable_id ?? index)}>
                {columns.map((column, columnIndex) => (
                  <td key={column}>
                    {(column === "stable_id" || column === "title") &&
                    typeof row.content_type === "string" ? (
                      <Link
                        className="record-link"
                        href={`/content/${encodeURIComponent(row.content_type)}/${encodeURIComponent(String(row.stable_id))}`}
                      >
                        {String(row[column])}
                      </Link>
                    ) : (
                      <Value value={row[column]} />
                    )}
                    {columnIndex === 0 &&
                      (String(row.stable_id ?? row.target_id ?? "").startsWith(
                        "demo.fyp.",
                      ) ||
                        String(row.source_name ?? "").startsWith("DEMO")) && (
                        <span className="demo-tag table-demo-tag">Demo</span>
                      )}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
        {!visible.length && (
          <div className="compact-empty">
            <Icon name="search" size={26} />
            <h3>No matching records</h3>
            <p>Try another search or status.</p>
            <button
              className="button secondary"
              onClick={() => {
                setQuery("");
                setStatus("");
              }}
            >
              Clear filters
            </button>
          </div>
        )}
      </div>
      <div className="panel-footer">
        <span>
          {ordered.length
            ? `${currentPage * 10 + 1}–${Math.min(currentPage * 10 + 10, ordered.length)}`
            : "0"}{" "}
          of {ordered.length} loaded records
        </span>
        <div className="pagination">
          <button
            className="button secondary"
            disabled={currentPage === 0}
            onClick={() => setPage(currentPage - 1)}
          >
            Previous
          </button>
          <span>
            {currentPage + 1} / {lastPage + 1}
          </span>
          <button
            className="button secondary"
            disabled={currentPage === lastPage}
            onClick={() => setPage(currentPage + 1)}
          >
            Next
          </button>
        </div>
      </div>
    </section>
  );
}
