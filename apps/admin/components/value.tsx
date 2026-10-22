const statuses = new Set([
  "draft",
  "in_review",
  "approved",
  "published",
  "archived",
  "deprecated",
  "open",
  "resolved",
  "rejected",
  "validated",
  "validation_failed",
  "applied",
  "ready",
]);

export function Value({ value }: { value: unknown }) {
  if (value === null || value === undefined)
    return <span className="muted">—</span>;
  if (typeof value === "boolean")
    return (
      <span className={`status ${value ? "status-published" : "status-draft"}`}>
        {value ? "Yes" : "No"}
      </span>
    );
  if (typeof value === "object")
    return (
      <details>
        <summary>View details</summary>
        <pre className="code">{JSON.stringify(value, null, 2)}</pre>
      </details>
    );
  if (typeof value === "string" && statuses.has(value))
    return (
      <span className={`status status-${value}`}>
        <i />
        {value.replaceAll("_", " ")}
      </span>
    );
  if (
    typeof value === "string" &&
    /^\d{4}-\d{2}-\d{2}T/.test(value) &&
    !Number.isNaN(Date.parse(value))
  ) {
    return (
      <time dateTime={value}>
        {new Intl.DateTimeFormat("en", {
          dateStyle: "medium",
          timeStyle: "short",
          timeZone: "UTC",
        }).format(new Date(value))}{" "}
        UTC
      </time>
    );
  }
  return <>{String(value)}</>;
}
