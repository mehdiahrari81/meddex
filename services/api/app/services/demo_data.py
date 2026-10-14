"""Explicit, repeatable local demonstration data. Never enabled by startup."""

import hashlib
import secrets
from datetime import timedelta
from typing import Any
from uuid import NAMESPACE_URL, uuid5

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.core.security import hash_password
from app.core.time import utc_now
from app.models import (
    AdminMembership,
    AuditEvent,
    ContentImportJob,
    GovernanceReport,
    GovernedContent,
    GovernedContentRevision,
    User,
    UserProfile,
)


def seed_demo_data(
    db: Session, settings: Settings, actor_email: str, dataset: dict[str, Any]
) -> dict[str, int]:
    if settings.environment not in {"development", "testing"}:
        raise ValueError("Demo data is restricted to development and testing.")
    actor = db.scalar(
        select(User)
        .join(AdminMembership, AdminMembership.user_id == User.id)
        .where(
            User.email == actor_email.lower(),
            User.is_active.is_(True),
            AdminMembership.active.is_(True),
        )
    )
    if actor is None:
        raise ValueError("Supply an existing active administrator's email.")
    author_id = uuid5(NAMESPACE_URL, "mediexplain:demo:fyp:author")
    if db.get(User, author_id) is None:
        db.add(
            User(
                id=author_id,
                email="demo.fyp.author@example.com",
                is_active=False,
                password_hash=hash_password(secrets.token_urlsafe(32)),
                profile=UserProfile(display_name="Demo content author (inactive)"),
            )
        )
        db.flush()
    now = utc_now()
    examples: list[tuple[str, dict[str, Any], str]] = []
    for key, kind, limit, title_key in (
        ("terms", "terminology", 8, "term"),
        ("morphology", "morphology", 4, "value"),
        ("abbreviations", "abbreviation", 4, "abbreviation"),
        ("lessons", "lesson", 2, "title"),
        ("quiz_questions", "quiz", 3, "prompt"),
    ):
        for item in dataset.get(key, [])[:limit]:
            examples.append((kind, dict(item), str(item[title_key])))
    for index, (english, urdu) in enumerate(
        [("Save", "محفوظ کریں"), ("Review", "جائزہ لیں"), ("Learning", "سیکھیں")]
    ):
        examples.append(
            (
                "translation",
                {
                    "id": f"translation-{index}",
                    "language": "ur",
                    "source_text": english,
                    "translation": urdu,
                },
                f"Urdu interface: {english}",
            )
        )
    states = (
        "published",
        "in_review",
        "draft",
        "published",
        "approved",
        "in_review",
        "published",
        "draft",
    )
    added = {"content": 0, "reports": 0, "imports": 0}
    identifiers = []
    for index, (kind, item, title) in enumerate(examples):
        stable_id = f"demo.fyp.{item['id']}"
        identifiers.append(stable_id)
        if db.get(GovernedContent, stable_id) is not None:
            continue
        state = states[index % len(states)]
        when = now - timedelta(days=index % 7, hours=1 + index // 7)
        db.add(
            GovernedContent(
                stable_id=stable_id,
                content_type=kind,
                lifecycle_state=state,
                current_revision=1,
                published_revision=1 if state == "published" else None,
                created_at=when - timedelta(hours=2),
                updated_at=when,
            )
        )
        db.flush()
        db.add(
            GovernedContentRevision(
                stable_id=stable_id,
                revision=1,
                content={**item, "title": title, "demo": True, "review_status": "demonstration"},
                source_metadata={
                    "demo": True,
                    "production_approved": False,
                    "provider": "Bundled development corpus / FYP demo",
                    "note": "Synthetic editorial exercise; not a production reference release.",
                },
                author_id=author_id,
                change_reason="FYP demonstration fixture",
                review_state=state,
                created_at=when - timedelta(hours=2),
                reviewer_id=actor.id if state in {"approved", "published"} else None,
                reviewed_at=when if state in {"approved", "published"} else None,
                published_at=when if state == "published" else None,
            )
        )
        db.add(
            AuditEvent(
                actor_id=actor.id,
                permission_context=["content.read"],
                action="content.demo_seed",
                target_type="content",
                target_id=stable_id,
                request_id="demo-fyp-seed",
                safe_metadata={"demo": True, "title": title, "state": state},
                occurred_at=when,
            )
        )
        added["content"] += 1
    report_examples = [
        ("translation", "translation_clarity", "open", "Review the Urdu label for clarity."),
        ("content", "source_attribution", "open", "Confirm source attribution before publication."),
        (
            "content",
            "definition_clarity",
            "in_review",
            "Simplify the example for first-time readers.",
        ),
        (
            "unsafe_ai",
            "missing_citation",
            "open",
            "Simulated safety exercise: verify citation handling.",
        ),
        ("content", "accessibility", "in_review", "Review terminology pronunciation guidance."),
        ("content", "duplicate_content", "resolved", "Demo duplicate review completed."),
    ]
    for index, (kind, reason, state, summary) in enumerate(report_examples):
        report_id = uuid5(NAMESPACE_URL, f"mediexplain:demo:fyp:report:{index}")
        if db.get(GovernanceReport, report_id) is not None:
            continue
        db.add(
            GovernanceReport(
                id=report_id,
                report_type=kind,
                target_type="content",
                target_id=identifiers[index % len(identifiers)],
                reason=reason,
                status=state,
                redacted_context={"demo": True, "summary": summary},
                created_at=now - timedelta(hours=index * 9 + 1),
                resolution_note="Synthetic review exercise completed."
                if state == "resolved"
                else None,
                resolved_by=actor.id if state == "resolved" else None,
                resolved_at=now - timedelta(hours=1) if state == "resolved" else None,
            )
        )
        added["reports"] += 1
    for index, reason in enumerate(["missing_registration_id", "missing_ingredient"]):
        job_id = uuid5(NAMESPACE_URL, f"mediexplain:demo:fyp:import:{index}")
        if db.get(ContentImportJob, job_id) is not None:
            continue
        db.add(
            ContentImportJob(
                id=job_id,
                dataset_type="drap_products",
                source_name=f"DEMO CSV · {reason.replace('_', ' ')}",
                source_version="demo-fyp-v1",
                content_hash=hashlib.sha256(reason.encode()).hexdigest(),
                status="validation_failed",
                dry_run=True,
                report={
                    "demo": True,
                    "added": 0,
                    "updated": 0,
                    "unchanged": 0,
                    "rejected": 1,
                    "warnings": [{"row": 1, "reason": reason}],
                },
                staged_payload={"records": []},
                created_by=actor.id,
                created_at=now - timedelta(hours=index * 12 + 2),
            )
        )
        added["imports"] += 1
    db.commit()
    return added
