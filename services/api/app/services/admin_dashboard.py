"""Permission-scoped, database-backed governance dashboard summaries."""

from datetime import timedelta

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.core.time import utc_now
from app.models import AuditEvent, GovernanceReport, GovernedContent, GovernedContentRevision


def dashboard_snapshot(
    db: Session, settings: Settings, permissions: frozenset[str], days: int
) -> dict[str, object]:
    now = utc_now()
    first_day = (now - timedelta(days=days - 1)).replace(hour=0, minute=0, second=0, microsecond=0)
    content: dict[str, object] | None = None
    reports: dict[str, object] | None = None
    recent_content: list[dict[str, object]] = []
    recent_reports: list[dict[str, object]] = []
    activity: list[dict[str, object]] = []
    daily: dict[str, int] = {}
    demo_count = 0
    if "content.read" in permissions:
        states = {
            state: count
            for state, count in db.execute(
                select(GovernedContent.lifecycle_state, func.count()).group_by(
                    GovernedContent.lifecycle_state
                )
            ).all()
        }
        types = db.execute(
            select(GovernedContent.content_type, func.count())
            .group_by(GovernedContent.content_type)
            .order_by(func.count().desc(), GovernedContent.content_type)
        ).all()
        demo_count = (
            db.scalar(
                select(func.count())
                .select_from(GovernedContent)
                .where(GovernedContent.stable_id.startswith("demo.fyp."))
            )
            or 0
        )
        content = {
            "total": sum(states.values()),
            "states": states,
            "types": [{"type": kind, "count": count} for kind, count in types],
        }
        rows = db.execute(
            select(GovernedContent, GovernedContentRevision)
            .join(
                GovernedContentRevision,
                (GovernedContentRevision.stable_id == GovernedContent.stable_id)
                & (GovernedContentRevision.revision == GovernedContent.current_revision),
            )
            .order_by(GovernedContent.updated_at.desc(), GovernedContent.stable_id)
            .limit(12)
        ).all()
        recent_content = [
            {
                "stable_id": record.stable_id,
                "title": str(
                    revision.content.get("title")
                    or revision.content.get("term")
                    or record.stable_id
                )[:160],
                "content_type": record.content_type,
                "state": record.lifecycle_state,
                "revision": record.current_revision,
                "updated_at": record.updated_at,
                "is_demo": record.stable_id.startswith("demo.fyp."),
            }
            for record, revision in rows
        ]
        daily = {
            str(day)[:10]: count
            for day, count in db.execute(
                select(func.date(AuditEvent.occurred_at), func.count())
                .where(
                    AuditEvent.occurred_at >= first_day,
                    AuditEvent.occurred_at <= now,
                    AuditEvent.action.startswith("content."),
                )
                .group_by(func.date(AuditEvent.occurred_at))
            ).all()
        }
    if "reports.review" in permissions:
        report_states = {
            state: count
            for state, count in db.execute(
                select(GovernanceReport.status, func.count()).group_by(GovernanceReport.status)
            ).all()
        }
        reports = {"total": sum(report_states.values()), "states": report_states}
        recent_reports = [
            {
                "id": str(row.id),
                "reason": row.reason,
                "type": row.report_type,
                "target_id": row.target_id,
                "status": row.status,
                "summary": str(row.redacted_context.get("summary") or row.reason)[:240],
                "created_at": row.created_at,
                "is_demo": row.redacted_context.get("demo") is True,
            }
            for row in db.scalars(
                select(GovernanceReport)
                .where(GovernanceReport.status.in_(["open", "in_review"]))
                .order_by(GovernanceReport.created_at.desc())
                .limit(4)
            )
        ]
    if "audit.read" in permissions:
        activity = [
            {
                "id": str(row.id),
                "action": row.action,
                "target_id": row.target_id,
                "target_type": row.target_type,
                "occurred_at": row.occurred_at,
                "is_demo": row.safe_metadata.get("demo") is True,
            }
            for row in db.scalars(
                select(AuditEvent).order_by(AuditEvent.occurred_at.desc()).limit(5)
            )
        ]
    return {
        "checked_at": now,
        "environment": settings.environment,
        "days": days,
        "demo_records": demo_count,
        "content": content,
        "reports": reports,
        "recent_content": recent_content,
        "recent_reports": recent_reports,
        "recent_activity": activity,
        "editorial_activity": [
            {
                "date": (first_day + timedelta(days=index)).date().isoformat(),
                "count": daily.get((first_day + timedelta(days=index)).date().isoformat(), 0),
            }
            for index in range(days)
        ]
        if content is not None
        else [],
    }
