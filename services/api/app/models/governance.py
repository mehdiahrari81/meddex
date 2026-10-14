from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import (
    JSON,
    Boolean,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    LargeBinary,
    String,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.time import utc_now
from app.db.base import Base


class AdminRole(Base):
    __tablename__ = "admin_roles"
    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    name: Mapped[str] = mapped_column(String(80), unique=True)
    description: Mapped[str] = mapped_column(String(500))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)


class AdminPermission(Base):
    __tablename__ = "admin_permissions"
    code: Mapped[str] = mapped_column(String(100), primary_key=True)
    description: Mapped[str] = mapped_column(String(500))


class AdminRolePermission(Base):
    __tablename__ = "admin_role_permissions"
    role_id: Mapped[UUID] = mapped_column(
        ForeignKey("admin_roles.id", ondelete="CASCADE"), primary_key=True
    )
    permission_code: Mapped[str] = mapped_column(
        ForeignKey("admin_permissions.code", ondelete="CASCADE"), primary_key=True
    )


class AdminMembership(Base):
    __tablename__ = "admin_memberships"
    user_id: Mapped[UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    role_id: Mapped[UUID] = mapped_column(
        ForeignKey("admin_roles.id", ondelete="RESTRICT"), index=True
    )
    active: Mapped[bool] = mapped_column(Boolean, default=True)
    mfa_enabled: Mapped[bool] = mapped_column(Boolean, default=False)
    mfa_secret_encrypted: Mapped[bytes | None] = mapped_column(LargeBinary)
    granted_by: Mapped[UUID | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"))
    granted_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)


class GovernedContent(Base):
    __tablename__ = "governed_content"
    __table_args__ = (Index("ix_governed_content_queue", "content_type", "lifecycle_state"),)
    stable_id: Mapped[str] = mapped_column(String(120), primary_key=True)
    content_type: Mapped[str] = mapped_column(String(40), index=True)
    lifecycle_state: Mapped[str] = mapped_column(String(30), index=True)
    current_revision: Mapped[int] = mapped_column(Integer)
    published_revision: Mapped[int | None] = mapped_column(Integer)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)


class GovernedContentRevision(Base):
    __tablename__ = "governed_content_revisions"
    __table_args__ = (UniqueConstraint("stable_id", "revision", name="uq_governed_revision"),)
    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    stable_id: Mapped[str] = mapped_column(
        ForeignKey("governed_content.stable_id", ondelete="CASCADE"), index=True
    )
    revision: Mapped[int] = mapped_column(Integer)
    content: Mapped[dict[str, object]] = mapped_column(JSON)
    source_metadata: Mapped[dict[str, object]] = mapped_column(JSON)
    author_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="RESTRICT"))
    change_reason: Mapped[str] = mapped_column(String(1000))
    review_state: Mapped[str] = mapped_column(String(30))
    reviewer_id: Mapped[UUID | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"))
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    published_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)


class GovernanceReport(Base):
    __tablename__ = "governance_reports"
    __table_args__ = (Index("ix_governance_reports_queue", "report_type", "status", "created_at"),)
    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    user_id: Mapped[UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), index=True
    )
    report_type: Mapped[str] = mapped_column(String(50))
    target_type: Mapped[str] = mapped_column(String(50))
    target_id: Mapped[str] = mapped_column(String(120))
    reason: Mapped[str] = mapped_column(String(80))
    redacted_context: Mapped[dict[str, object]] = mapped_column(JSON, default=dict)
    status: Mapped[str] = mapped_column(String(30), default="open", index=True)
    resolution_note: Mapped[str | None] = mapped_column(String(2000))
    resolved_by: Mapped[UUID | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class ContentImportJob(Base):
    __tablename__ = "content_import_jobs"
    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    dataset_type: Mapped[str] = mapped_column(String(50), index=True)
    source_name: Mapped[str] = mapped_column(String(300))
    source_version: Mapped[str] = mapped_column(String(120))
    content_hash: Mapped[str] = mapped_column(String(64))
    status: Mapped[str] = mapped_column(String(30), index=True)
    dry_run: Mapped[bool] = mapped_column(Boolean, default=True)
    report: Mapped[dict[str, object]] = mapped_column(JSON, default=dict)
    staged_payload: Mapped[dict[str, object]] = mapped_column(JSON, default=dict)
    created_by: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="RESTRICT"))
    applied_by: Mapped[UUID | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    applied_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class AuditEvent(Base):
    __tablename__ = "audit_events"
    __table_args__ = (Index("ix_audit_target_time", "target_type", "target_id", "occurred_at"),)
    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    actor_id: Mapped[UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), index=True
    )
    permission_context: Mapped[list[str]] = mapped_column(JSON, default=list)
    action: Mapped[str] = mapped_column(String(120), index=True)
    target_type: Mapped[str] = mapped_column(String(80))
    target_id: Mapped[str] = mapped_column(String(160))
    request_id: Mapped[str] = mapped_column(String(100), index=True)
    safe_metadata: Mapped[dict[str, object]] = mapped_column(JSON, default=dict)
    before_reference: Mapped[str | None] = mapped_column(String(300))
    after_reference: Mapped[str | None] = mapped_column(String(300))
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
