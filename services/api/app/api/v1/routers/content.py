from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select

from app.api.dependencies import DatabaseDependency, SettingsDependency
from app.models import ContentReport, ContentVersion, GovernedContent, GovernedContentRevision
from app.schemas.module2 import ContentReportCreate, ContentReportRead, ContentVersionRead

router = APIRouter(tags=["content"])


@router.get("/content/dataset")
def published_dataset(db: DatabaseDependency, settings: SettingsDependency) -> dict[str, object]:
    candidates = db.scalars(
        select(GovernedContentRevision)
        .join(GovernedContent, GovernedContent.stable_id == GovernedContentRevision.stable_id)
        .where(
            GovernedContent.content_type == "dataset",
            GovernedContent.published_revision == GovernedContentRevision.revision,
            GovernedContentRevision.review_state == "published",
        )
        .order_by(GovernedContentRevision.published_at.desc())
    ).all()
    for revision in candidates:
        if (
            settings.environment != "production"
            or revision.content.get("production_approved") is True
        ):
            return revision.content
    raise HTTPException(status_code=404, detail="No approved reference release is available")


@router.get("/content/version", response_model=ContentVersionRead)
def content_version(db: DatabaseDependency) -> ContentVersionRead:
    # The compiled mobile release is authoritative, even if an uploaded file
    # carries an arbitrary generated_at timestamp.
    release = db.get(GovernedContent, "reference.mobile")
    if release is not None and release.published_revision is not None:
        revision = db.scalar(
            select(GovernedContentRevision).where(
                GovernedContentRevision.stable_id == release.stable_id,
                GovernedContentRevision.revision == release.published_revision,
            )
        )
        if revision is not None:
            current = db.get(ContentVersion, str(revision.content["dataset_name"]))
            if current is not None:
                return ContentVersionRead.model_validate(current)
    value = db.scalar(select(ContentVersion).order_by(ContentVersion.updated_at.desc()))
    if value is None:
        from fastapi import HTTPException

        raise HTTPException(status_code=404, detail="No content dataset installed")
    return ContentVersionRead.model_validate(value)


@router.post(
    "/reports/content", response_model=ContentReportRead, status_code=status.HTTP_201_CREATED
)
def content_report(
    payload: ContentReportCreate,
    db: DatabaseDependency,
) -> ContentReportRead:
    # Reports may be anonymous so safety feedback is accessible without an account.
    data = payload.model_dump(exclude={"id"})
    if payload.id:
        existing = db.get(ContentReport, payload.id)
        if existing is not None:
            return ContentReportRead.model_validate(existing)
        value = ContentReport(id=payload.id, user_id=None, **data)
    else:
        value = ContentReport(user_id=None, **data)
    db.add(value)
    db.commit()
    db.refresh(value)
    return ContentReportRead.model_validate(value)
