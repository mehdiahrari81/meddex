from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import EmailStr, Field

from app.schemas.common import StrictSchema


class AdminLoginRequest(StrictSchema):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)
    mfa_code: str | None = Field(default=None, pattern=r"^\d{6}$")


class AdminSessionRead(StrictSchema):
    session_id: UUID
    access_token: str
    access_token_expires_at: datetime
    permissions: list[str]
    role: str


class AdminMeRead(StrictSchema):
    user_id: UUID
    email: EmailStr
    role: str
    permissions: list[str]
    session_id: UUID


class GovernedContentCreate(StrictSchema):
    stable_id: str = Field(min_length=1, max_length=120, pattern=r"^[A-Za-z0-9._-]+$")
    content_type: Literal[
        "terminology", "morphology", "abbreviation", "lesson", "quiz", "translation", "dataset"
    ]
    content: dict[str, object]
    source_metadata: dict[str, object]
    change_reason: str = Field(min_length=3, max_length=1000)


class GovernedContentRead(StrictSchema):
    stable_id: str
    content_type: str
    lifecycle_state: str
    current_revision: int
    published_revision: int | None
    updated_at: datetime


class WorkflowActionRequest(StrictSchema):
    action: Literal["submit_review", "approve", "reject", "publish", "deprecate", "archive"]
    reason: str = Field(min_length=3, max_length=1000)
    confirmation: str | None = Field(default=None, max_length=200)


class GovernedRevisionRead(StrictSchema):
    id: UUID
    stable_id: str
    revision: int
    content: dict[str, object]
    source_metadata: dict[str, object]
    author_id: UUID
    change_reason: str
    review_state: str
    reviewer_id: UUID | None
    reviewed_at: datetime | None
    published_at: datetime | None
    created_at: datetime


class ImportDryRunRequest(StrictSchema):
    dataset_type: Literal["drap_products"]
    source_name: str = Field(min_length=1, max_length=300)
    source_version: str = Field(min_length=1, max_length=120)
    records: list[dict[str, object]] = Field(min_length=1, max_length=10_000)


class ImportJobRead(StrictSchema):
    id: UUID
    dataset_type: str
    source_name: str
    source_version: str
    status: str
    dry_run: bool
    report: dict[str, object]
    created_at: datetime


class ImportApplyRequest(StrictSchema):
    confirmation: str


class FeatureFlagUpdate(StrictSchema):
    enabled: bool
    expected_revision: int = Field(ge=1)
    confirmation: str | None = Field(default=None, max_length=200)


class FeatureFlagRead(StrictSchema):
    key: str
    enabled: bool
    description: str
    revision: int
    updated_at: datetime


class ReportWorkflowRequest(StrictSchema):
    status: Literal["in_review", "resolved", "rejected"]
    resolution_note: str = Field(min_length=3, max_length=2000)
    confirmation: str = Field(min_length=1, max_length=200)


class ResolutionAnnotationRequest(StrictSchema):
    note: str = Field(min_length=3, max_length=1000)
    review_status: Literal["needs_source", "reviewed_no_override", "candidate_investigation"]
