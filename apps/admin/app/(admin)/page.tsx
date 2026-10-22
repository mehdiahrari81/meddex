import Link from "next/link";
import { redirect } from "next/navigation";
import { api, currentAdmin } from "@/lib/api";
import { permittedNavigation } from "@/lib/nav";
import { friendly, shortDate, type DashboardSnapshot } from "@/lib/dashboard";
import { Icon, type IconName } from "@/components/icon";
import {
  ActivityPeriod,
  RecentContentTable,
  RefreshDashboard,
} from "@/components/dashboard-widgets";

type Health = {
  database: string;
  latest_import: string | null;
  open_reports: number;
  checked_at: string;
};
type Provider = {
  provider: string;
  requests: number;
  success_rate: number | null;
  average_latency_ms: number | null;
};

function MetricCard({
  label,
  value,
  detail,
  icon,
  tone,
  href,
}: {
  label: string;
  value: number | string;
  detail: string;
  icon: IconName;
  tone: string;
  href?: string;
}) {
  return (
    <article className="metric-card">
      <div className="metric-label">
        {label}
        <span className={`metric-icon tone-${tone}`}>
          <Icon name={icon} size={19} />
        </span>
      </div>
      <div className="metric-value">
        {typeof value === "number" ? value.toLocaleString("en") : value}
      </div>
      <div className="metric-detail">
        {detail}
        {href && (
          <Link href={href} aria-label={`View ${label.toLowerCase()}`}>
            <Icon name="arrow" size={16} />
          </Link>
        )}
      </div>
    </article>
  );
}

export default async function Dashboard({
  searchParams,
}: {
  searchParams: Promise<{ days?: string }>;
}) {
  const admin = await currentAdmin();
  if (!admin.permissions.includes("system.read"))
    redirect(
      permittedNavigation(admin.permissions)[0]?.items[0]?.href ?? "/login",
    );
  const requested = Number((await searchParams).days ?? 7);
  const days = [7, 14, 30].includes(requested) ? requested : 7;
  const [snapshot, health, providers] = await Promise.all([
    api<DashboardSnapshot>(`/admin/dashboard?days=${days}`),
    api<Health>("/admin/system-health"),
    api<Provider[]>("/admin/provider-health"),
  ]);
  const { content, reports } = snapshot;
  const totalEvents = snapshot.editorial_activity.reduce(
    (sum, row) => sum + row.count,
    0,
  );
  const maximum = Math.max(
    1,
    ...snapshot.editorial_activity.map((row) => row.count),
  );
  const providerRequests = providers.reduce(
    (sum, row) => sum + row.requests,
    0,
  );
  const labels = ["published", "in_review", "draft", "approved"];
  const other = content
    ? content.total -
      labels.reduce((sum, key) => sum + (content.states[key] ?? 0), 0)
    : 0;
  const distribution = [
    ...labels.map((key) => ({ key, count: content?.states[key] ?? 0 })),
    ...(other > 0 ? [{ key: "other", count: other }] : []),
  ];
  const colors = ["#18856f", "#e2a64a", "#cbd5e1", "#8290c9", "#52657b"];
  let position = 0;
  const gradient = distribution
    .map((item, index) => {
      const start = position;
      position += content?.total ? (item.count / content.total) * 100 : 0;
      return `${colors[index]} ${start}% ${position}%`;
    })
    .join(", ");
  const canEdit = admin.permissions.includes("content.edit");
  const canReview = admin.permissions.includes("content.review");
  return (
    <div className="dashboard">
      <div className="dashboard-heading">
        <div>
          <div className="eyebrow">Workspace overview</div>
          <h1>Governance dashboard</h1>
          <p>
            Review content, resolve reports, and keep every release accountable.
          </p>
        </div>
        <div className="toolbar">
          <RefreshDashboard />
          {canEdit && (
            <Link className="button" href="/content/terminology/new">
              <Icon name="plus" size={17} />
              Create draft
            </Link>
          )}
        </div>
      </div>
      <div className="workspace-context">
        <span>
          <span
            className={`live-dot ${health.database !== "ready" ? "is-warning" : ""}`}
          />
          {health.database === "ready"
            ? "Database connected"
            : "Database needs attention"}
        </span>
        <span className="context-date">
          <Icon name="clock" size={14} />
          <time dateTime={snapshot.checked_at}>
            {new Intl.DateTimeFormat("en", {
              weekday: "long",
              month: "long",
              day: "numeric",
              timeZone: "UTC",
            }).format(new Date(snapshot.checked_at))}
          </time>
        </span>
      </div>
      {snapshot.demo_records > 0 && (
        <aside className="demo-notice">
          <Icon name="flask" size={17} />
          <span>
            <strong>FYP demo workspace</strong>
            <span className="notice-divider">·</span>
            {snapshot.demo_records} sample content records. Service health and
            provider activity reflect actual checks.
          </span>
          <span className="demo-tag">Demo data</span>
        </aside>
      )}
      <section className="metric-grid" aria-label="System overview">
        <MetricCard
          label="Content records"
          value={content?.total ?? "—"}
          detail={
            content
              ? `${content.states.published ?? 0} published in the editorial library`
              : "Content access restricted"
          }
          icon="book"
          tone="green"
          href={content ? "/content/terminology" : undefined}
        />
        <MetricCard
          label="Awaiting review"
          value={content?.states.in_review ?? (content ? 0 : "—")}
          detail={
            content
              ? `${content.states.approved ?? 0} approved and ready for publishing`
              : "Content access restricted"
          }
          icon="inbox"
          tone="amber"
          href={canReview ? "/review" : undefined}
        />
        <MetricCard
          label="Reports to resolve"
          value={
            reports
              ? (reports.states.open ?? 0) + (reports.states.in_review ?? 0)
              : "—"
          }
          detail={
            reports
              ? `${reports.states.open ?? 0} open · ${reports.states.in_review ?? 0} in review`
              : "Report access restricted"
          }
          icon="shield"
          tone="blue"
          href={reports ? "/reports" : undefined}
        />
        <MetricCard
          label="Provider requests"
          value={providerRequests}
          detail="Recorded over the last 24 hours"
          icon="activity"
          tone="purple"
          href="/providers"
        />
      </section>
      {content && (
        <section className="overview-grid" aria-label="Content analytics">
          <article className="panel activity-panel">
            <div className="panel-heading">
              <div>
                <h2>Editorial activity</h2>
                <p>Recorded content events, by day</p>
              </div>
              <ActivityPeriod days={days} />
            </div>
            <div className="chart-summary">
              <strong>{totalEvents}</strong>
              <span>events in the last {days} days</span>
              <span className="chart-key">
                <i />
                Editorial events
              </span>
            </div>
            <div
              className="bar-chart"
              role="img"
              aria-label={`${totalEvents} editorial events over ${days} days. ${snapshot.editorial_activity.map((row) => `${row.date}: ${row.count}`).join("; ")}`}
            >
              <div className="chart-guide">
                <span>{maximum}</span>
                <span>{Math.round(maximum / 2)}</span>
                <span>0</span>
              </div>
              <div className="chart-columns">
                {snapshot.editorial_activity.map((row, index) => (
                  <div className="chart-column" key={row.date}>
                    <div className="chart-bar-space">
                      <div
                        className={`chart-bar ${row.count === 0 ? "zero" : ""}`}
                        style={{
                          height: `${Math.max(2, (row.count / maximum) * 100)}%`,
                        }}
                        title={`${shortDate(row.date)}: ${row.count} events`}
                      >
                        <span>{row.count}</span>
                      </div>
                    </div>
                    <span className="chart-date">
                      {days <= 7 ||
                      index % Math.ceil(days / 7) === 0 ||
                      index === days - 1
                        ? shortDate(row.date)
                        : ""}
                    </span>
                  </div>
                ))}
              </div>
            </div>
            <div className="chart-caption">
              All dates are in UTC.
              {snapshot.demo_records > 0 ? " Demo records are included." : ""}
            </div>
          </article>
          <article className="panel distribution-panel">
            <div className="panel-heading">
              <div>
                <h2>Content pipeline</h2>
                <p>Every record, at a glance</p>
              </div>
              <Icon name="layers" size={19} />
            </div>
            <div className="distribution">
              <div
                className="donut"
                role="img"
                aria-label={distribution
                  .map((item) => `${friendly(item.key)}: ${item.count}`)
                  .join(", ")}
                style={{
                  background: content.total
                    ? `conic-gradient(${gradient})`
                    : "#e9eef1",
                }}
              >
                <div>
                  <strong>{content.total}</strong>
                  <span>Total records</span>
                </div>
              </div>
              <div className="distribution-legend">
                {distribution.map((item, index) => (
                  <div key={item.key}>
                    <span>
                      <i style={{ background: colors[index] }} />
                      {friendly(item.key)}
                    </span>
                    <strong>{item.count}</strong>
                  </div>
                ))}
              </div>
            </div>
            <div className="pipeline-footer">
              <Icon name="shield" size={15} />
              <span>Independent review before publication</span>
            </div>
          </article>
        </section>
      )}
      <section className="work-grid" aria-label="Review workspace">
        {content && (
          <article className="panel library-panel">
            <div className="panel-heading">
              <div>
                <h2>Recent content</h2>
                <p>The latest records in your editorial library</p>
              </div>
              {canReview && (
                <Link className="text-link" href="/review">
                  Review queue <Icon name="arrow" size={15} />
                </Link>
              )}
            </div>
            <RecentContentTable rows={snapshot.recent_content} />
          </article>
        )}
        {reports && (
          <article className="panel inbox-panel">
            <div className="panel-heading">
              <div>
                <h2>Review inbox</h2>
                <p>Reports that need a closer look</p>
              </div>
              <span className="count-badge">
                {(reports.states.open ?? 0) + (reports.states.in_review ?? 0)}
              </span>
            </div>
            <div className="report-list">
              {snapshot.recent_reports.length ? (
                snapshot.recent_reports.map((report) => (
                  <Link
                    className="report-item"
                    key={report.id}
                    href={`/reports?report=${report.id}`}
                  >
                    <span
                      className={`report-icon ${report.type === "unsafe_ai" ? "safety" : ""}`}
                    >
                      <Icon
                        name={report.type === "unsafe_ai" ? "shield" : "report"}
                        size={18}
                      />
                    </span>
                    <div>
                      <div className="report-title">
                        {friendly(report.reason)}
                        {report.is_demo && (
                          <span className="demo-tag">Demo</span>
                        )}
                      </div>
                      <p>{report.summary}</p>
                      <span className="report-meta">
                        <span className={`status status-${report.status}`}>
                          <i />
                          {friendly(report.status)}
                        </span>
                        <time dateTime={report.created_at}>
                          {shortDate(report.created_at)}
                        </time>
                      </span>
                    </div>
                    <Icon name="chevron" size={16} />
                  </Link>
                ))
              ) : (
                <div className="compact-empty">
                  <Icon name="check" size={30} />
                  <h3>You’re all caught up</h3>
                  <p>No open reports need attention.</p>
                </div>
              )}
            </div>
            <div className="panel-footer">
              <span>{reports.total} reports in total</span>
              <Link href="/reports">
                View all reports <Icon name="arrow" size={14} />
              </Link>
            </div>
          </article>
        )}
      </section>
      <section
        className="work-grid bottom-grid"
        aria-label="Workspace operations"
      >
        {admin.permissions.includes("audit.read") && (
          <article className="panel">
            <div className="panel-heading">
              <div>
                <h2>Recent activity</h2>
                <p>A traceable record of workspace changes</p>
              </div>
              <Link className="text-link" href="/audit">
                Audit log <Icon name="arrow" size={15} />
              </Link>
            </div>
            <div className="activity-feed">
              {snapshot.recent_activity.length ? (
                snapshot.recent_activity.map((event) => (
                  <div className="feed-item" key={event.id}>
                    <span className="feed-icon">
                      <Icon
                        name={
                          event.action.includes("publish") ? "check" : "layers"
                        }
                        size={15}
                      />
                    </span>
                    <div>
                      <strong>
                        {event.action === "content.demo_seed"
                          ? "Demo content added"
                          : friendly(event.action)}
                      </strong>
                      <p>
                        {friendly(
                          event.target_id.replace(/^demo\.fyp\./, ""),
                        ).replaceAll("-", " ")}
                      </p>
                    </div>
                    <time dateTime={event.occurred_at}>
                      {shortDate(event.occurred_at)}
                    </time>
                  </div>
                ))
              ) : (
                <div className="compact-empty">
                  <p>Workspace changes will appear here.</p>
                </div>
              )}
            </div>
          </article>
        )}
        <article className="panel">
          <div className="panel-heading">
            <div>
              <h2>Service overview</h2>
              <p>Observed status, without assumptions</p>
            </div>
            <Icon name="server" size={19} />
          </div>
          <div className="service-list">
            <div className="service-row">
              <span className="service-icon">
                <Icon name="server" size={19} />
              </span>
              <div>
                <strong>Application database</strong>
                <span>
                  Checked{" "}
                  {new Intl.DateTimeFormat("en", {
                    hour: "2-digit",
                    minute: "2-digit",
                    timeZone: "UTC",
                  }).format(new Date(health.checked_at))}{" "}
                  UTC
                </span>
              </div>
              <span
                className={`status ${health.database === "ready" ? "status-published" : "status-open"}`}
              >
                <i />
                {health.database === "ready" ? "Connected" : "Attention"}
              </span>
            </div>
            {providers.length ? (
              providers.map((provider) => (
                <div className="service-row" key={provider.provider}>
                  <span className="service-icon">
                    <Icon name="globe" size={19} />
                  </span>
                  <div>
                    <strong>{friendly(provider.provider)}</strong>
                    <span>
                      {provider.requests} requests ·{" "}
                      {provider.average_latency_ms === null
                        ? "Latency unavailable"
                        : `${Math.round(provider.average_latency_ms)} ms average`}
                    </span>
                  </div>
                  <span className="status status-draft">
                    {provider.success_rate === null
                      ? "No rate"
                      : `${Math.round(provider.success_rate * 100)}% success`}
                  </span>
                </div>
              ))
            ) : (
              <div className="service-row">
                <span className="service-icon">
                  <Icon name="globe" size={19} />
                </span>
                <div>
                  <strong>External providers</strong>
                  <span>No calls recorded in the last 24 hours</span>
                </div>
                <span className="status status-draft">No activity</span>
              </div>
            )}
          </div>
          <div className="panel-footer">
            <span>Updated on page refresh</span>
            <Link href="/system-health">
              System health <Icon name="arrow" size={14} />
            </Link>
          </div>
        </article>
      </section>
      <footer className="workspace-footnote">
        <span>
          <Icon name="shield" size={14} />
          MediExplain governance workspace
        </span>
        <span>Reviewed content. Visible provenance. Accountable changes.</span>
      </footer>
    </div>
  );
}
