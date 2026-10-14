from datetime import timedelta
from typing import Annotated, cast
from uuid import UUID

from fastapi import (
    APIRouter,
    Depends,
    File,
    Form,
    HTTPException,
    Query,
    Request,
    Response,
    UploadFile,
    status,
)
from sqlalchemy import case, func, select

from app.api.dependencies import (
    CurrentAdmin,
    CurrentAdminDependency,
    DatabaseDependency,
    SettingsDependency,
    require_permission,
)
from app.core.middleware import RequestMetrics
from app.core.time import utc_now
from app.models import (
    AdminMembership,
    AdminPermission,
    AdminRole,
    AdminRolePermission,
    AuditEvent,
    AuthSession,
    ContentImportJob,
    FeatureFlag,
    GovernanceReport,
    GovernedContent,
    GovernedContentRevision,
    MedicalFact,
    MedicationResolution,
    ProviderHealthEvent,
    User,
)
from app.schemas.admin import (
    AdminLoginRequest,
    AdminMeRead,
    AdminSessionRead,
    FeatureFlagRead,
    FeatureFlagUpdate,
    GovernedContentCreate,
    GovernedContentRead,
    GovernedRevisionRead,
    ImportApplyRequest,
    ImportDryRunRequest,
    ImportJobRead,
    ReportWorkflowRequest,
    ResolutionAnnotationRequest,
    WorkflowActionRequest,
)
from app.services.admin_auth import AdminAuthService
from app.services.admin_dashboard import dashboard_snapshot
from app.services.governance import GovernanceService

router = APIRouter(prefix="/admin", tags=["admin"])


@router.post("/auth/login", response_model=AdminSessionRead)
def login(
    payload: AdminLoginRequest,
    db: DatabaseDependency,
    settings: SettingsDependency,
) -> AdminSessionRead:
    try:
        return AdminSessionRead.model_validate(
            AdminAuthService(db, settings).login(payload.email, payload.password, payload.mfa_code)
        )
    except ValueError as error:
        raise HTTPException(status_code=401, detail="Invalid administrative credentials") from error
    except PermissionError as error:
        raise HTTPException(
            status_code=403, detail="Administrative MFA enrollment is required"
        ) from error


@router.get("/me", response_model=AdminMeRead)
def me(admin: CurrentAdminDependency) -> AdminMeRead:
    return AdminMeRead(
        user_id=admin.user.id,
        email=admin.user.email,
        role=admin.role,
        permissions=sorted(admin.permissions),
        session_id=admin.auth_session.id,
    )


@router.post("/auth/logout", status_code=204)
def logout(admin: CurrentAdminDependency, db: DatabaseDependency) -> Response:
    admin.auth_session.revoked_at = utc_now()
    db.commit()
    return Response(status_code=204)


ContentReadAdmin = Annotated[CurrentAdmin, Depends(require_permission("content.read"))]
ContentEditAdmin = Annotated[CurrentAdmin, Depends(require_permission("content.edit"))]
ContentReviewAdmin = Annotated[CurrentAdmin, Depends(require_permission("content.review"))]
ContentPublishAdmin = Annotated[CurrentAdmin, Depends(require_permission("content.publish"))]
SourceManageAdmin = Annotated[CurrentAdmin, Depends(require_permission("sources.manage"))]
ReportReviewAdmin = Annotated[CurrentAdmin, Depends(require_permission("reports.review"))]
AuditReadAdmin = Annotated[CurrentAdmin, Depends(require_permission("audit.read"))]
SystemReadAdmin = Annotated[CurrentAdmin, Depends(require_permission("system.read"))]
SystemManageAdmin = Annotated[CurrentAdmin, Depends(require_permission("system.manage"))]


@router.get("/dashboard")
def dashboard(
    admin: SystemReadAdmin,
    db: DatabaseDependency,
    settings: SettingsDependency,
    days: Annotated[int, Query(ge=1, le=30)] = 7,
) -> dict[str, object]:
    return dashboard_snapshot(db, settings, frozenset(admin.permissions), days)


@router.get("/content", response_model=list[GovernedContentRead])
def list_content(
    admin: ContentReadAdmin, db: DatabaseDependency, offset: int = 0, limit: int = 50
) -> list[GovernedContentRead]:
    values = db.scalars(
        select(GovernedContent)
        .order_by(GovernedContent.updated_at.desc())
        .offset(max(0, offset))
        .limit(min(max(1, limit), 100))
    ).all()
    return [GovernedContentRead.model_validate(item, from_attributes=True) for item in values]


@router.get("/content/{stable_id}", response_model=GovernedContentRead)
def read_content(
    stable_id: str, admin: ContentReadAdmin, db: DatabaseDependency
) -> GovernedContentRead:
    record = db.get(GovernedContent, stable_id)
    if record is None:
        raise HTTPException(status_code=404, detail="Content not found")
    return GovernedContentRead.model_validate(record, from_attributes=True)


@router.get("/content/{stable_id}/revisions", response_model=list[GovernedRevisionRead])
def content_revisions(
    stable_id: str,
    admin: ContentReadAdmin,
    db: DatabaseDependency,
    offset: int = 0,
    limit: int = 10,
) -> list[GovernedRevisionRead]:
    if db.get(GovernedContent, stable_id) is None:
        raise HTTPException(status_code=404, detail="Content not found")
    rows = db.scalars(
        select(GovernedContentRevision)
        .where(GovernedContentRevision.stable_id == stable_id)
        .order_by(GovernedContentRevision.revision.desc())
        .offset(max(0, offset))
        .limit(min(50, max(1, limit)))
    ).all()
    return [GovernedRevisionRead.model_validate(row, from_attributes=True) for row in rows]


@router.post("/content", response_model=GovernedContentRead, status_code=status.HTTP_201_CREATED)
def create_content(
    payload: GovernedContentCreate,
    request: Request,
    admin: ContentEditAdmin,
    db: DatabaseDependency,
    settings: SettingsDependency,
) -> GovernedContentRead:
    if len(payload.model_dump_json().encode()) > settings.max_import_bytes:
        raise HTTPException(status_code=413, detail="Content exceeds configured size limit")
    try:
        value = GovernanceService(db).create_revision(
            stable_id=payload.stable_id,
            content_type=payload.content_type,
            content=payload.content,
            source_metadata=payload.source_metadata,
            reason=payload.change_reason,
            actor_id=admin.user.id,
            permissions=sorted(admin.permissions),
            request_id=request.state.request_id,
        )
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    return GovernedContentRead.model_validate(value, from_attributes=True)


@router.post("/content/{stable_id}/workflow", response_model=GovernedContentRead)
def content_workflow(
    stable_id: str,
    payload: WorkflowActionRequest,
    request: Request,
    admin: CurrentAdminDependency,
    db: DatabaseDependency,
    settings: SettingsDependency,
) -> GovernedContentRead:
    required = {
        "submit_review": "content.edit",
        "approve": "content.review",
        "reject": "content.review",
        "publish": "content.publish",
        "deprecate": "content.publish",
        "archive": "content.publish",
    }.get(payload.action, "content.review")
    if required not in admin.permissions:
        raise HTTPException(status_code=403, detail="Permission denied")
    if payload.action == "publish" and settings.environment == "production":
        record = db.get(GovernedContent, stable_id)
        if record is not None and record.content_type == "dataset":
            revision = db.scalar(
                select(GovernedContentRevision).where(
                    GovernedContentRevision.stable_id == stable_id,
                    GovernedContentRevision.revision == record.current_revision,
                )
            )
            if revision is None or revision.content.get("production_approved") is not True:
                raise HTTPException(
                    status_code=409, detail="Reference release is not production-approved"
                )
    try:
        value = GovernanceService(db).workflow(
            stable_id=stable_id,
            action=payload.action,
            reason=payload.reason,
            confirmation=payload.confirmation,
            actor_id=admin.user.id,
            permissions=sorted(admin.permissions),
            request_id=request.state.request_id,
        )
    except LookupError as error:
        raise HTTPException(status_code=404, detail="Content not found") from error
    except ValueError as error:
        raise HTTPException(status_code=409, detail=str(error)) from error
    return GovernedContentRead.model_validate(value, from_attributes=True)


@router.post("/imports/dry-run", response_model=ImportJobRead, status_code=201)
def import_dry_run(
    payload: ImportDryRunRequest,
    request: Request,
    admin: SourceManageAdmin,
    db: DatabaseDependency,
    settings: SettingsDependency,
) -> ImportJobRead:
    size = len(payload.model_dump_json().encode())
    if size > settings.max_import_bytes:
        raise HTTPException(status_code=413, detail="Import exceeds configured size limit")
    value = GovernanceService(db).dry_run_import(
        dataset_type=payload.dataset_type,
        source_name=payload.source_name,
        source_version=payload.source_version,
        records=payload.records,
        actor_id=admin.user.id,
        permissions=sorted(admin.permissions),
        request_id=request.state.request_id,
    )
    return ImportJobRead.model_validate(value, from_attributes=True)


@router.post("/imports/drap/upload", response_model=ImportJobRead, status_code=201)
async def import_drap_upload(
    request: Request,
    admin: SourceManageAdmin,
    db: DatabaseDependency,
    settings: SettingsDependency,
    file: Annotated[UploadFile, File()],
    source_name: Annotated[str, Form(min_length=1, max_length=300)],
    source_version: Annotated[str, Form(min_length=1, max_length=120)],
) -> ImportJobRead:
    from app.services.drap_parser import DrapParser

    try:
        content = await file.read(settings.max_import_bytes + 1)
        if len(content) > settings.max_import_bytes:
            raise HTTPException(status_code=413, detail="Import exceeds configured size limit")
        records = DrapParser.parse_csv(content)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=f"CSV parsing error: {error}") from error
    finally:
        await file.close()

    value = GovernanceService(db).dry_run_import(
        dataset_type="drap_products",
        source_name=source_name,
        source_version=source_version,
        records=records,
        actor_id=admin.user.id,
        permissions=sorted(admin.permissions),
        request_id=request.state.request_id,
    )
    return ImportJobRead.model_validate(value, from_attributes=True)


@router.post("/imports/{job_id}/apply", response_model=ImportJobRead)
def import_apply(
    job_id: UUID,
    payload: ImportApplyRequest,
    request: Request,
    admin: SourceManageAdmin,
    db: DatabaseDependency,
) -> ImportJobRead:
    try:
        value = GovernanceService(db).apply_import(
            job_id=job_id,
            confirmation=payload.confirmation,
            actor_id=admin.user.id,
            permissions=sorted(admin.permissions),
            request_id=request.state.request_id,
        )
    except LookupError as error:
        raise HTTPException(status_code=404, detail="Import job not found") from error
    except ValueError as error:
        raise HTTPException(status_code=409, detail=str(error)) from error
    return ImportJobRead.model_validate(value, from_attributes=True)


@router.get("/imports", response_model=list[ImportJobRead])
def imports(
    admin: SourceManageAdmin, db: DatabaseDependency, offset: int = 0, limit: int = 50
) -> list[ImportJobRead]:
    values = db.scalars(
        select(ContentImportJob)
        .order_by(ContentImportJob.created_at.desc())
        .offset(max(0, offset))
        .limit(min(max(1, limit), 100))
    ).all()
    return [ImportJobRead.model_validate(item, from_attributes=True) for item in values]


@router.get("/provider-health")
def provider_health(admin: SystemReadAdmin, db: DatabaseDependency) -> list[dict[str, object]]:
    since = utc_now() - timedelta(hours=24)
    rows = db.execute(
        select(
            ProviderHealthEvent.provider,
            func.count(ProviderHealthEvent.id),
            func.sum(case((ProviderHealthEvent.success.is_(True), 1), else_=0)),
            func.avg(ProviderHealthEvent.latency_ms),
            func.max(
                case((ProviderHealthEvent.success.is_(True), ProviderHealthEvent.occurred_at))
            ),
            func.max(ProviderHealthEvent.occurred_at),
        )
        .where(ProviderHealthEvent.occurred_at >= since)
        .group_by(ProviderHealthEvent.provider)
    ).all()
    return [
        {
            "provider": row[0],
            "requests": row[1],
            "successes": row[2] or 0,
            "success_rate": (row[2] or 0) / row[1] if row[1] else None,
            "average_latency_ms": row[3],
            "latest_success": row[4],
            "latest_request": row[5],
        }
        for row in rows
    ]


@router.get("/reports")
def reports(
    admin: ReportReviewAdmin, db: DatabaseDependency, offset: int = 0, limit: int = 50
) -> list[dict[str, object]]:
    values = db.scalars(
        select(GovernanceReport)
        .order_by(GovernanceReport.created_at.desc())
        .offset(max(0, offset))
        .limit(min(max(1, limit), 100))
    ).all()
    return [
        {
            "id": item.id,
            "report_type": item.report_type,
            "target_type": item.target_type,
            "target_id": item.target_id,
            "reason": item.reason,
            "redacted_context": item.redacted_context,
            "status": item.status,
            "created_at": item.created_at,
        }
        for item in values
    ]


@router.post("/reports/{report_id}/workflow")
def report_workflow(
    report_id: UUID,
    payload: ReportWorkflowRequest,
    request: Request,
    admin: ReportReviewAdmin,
    db: DatabaseDependency,
) -> dict[str, object]:
    value = db.get(GovernanceReport, report_id)
    if value is None:
        raise HTTPException(status_code=404, detail="Report not found")
    if payload.confirmation != str(report_id):
        raise HTTPException(status_code=409, detail="Typed confirmation is required")
    value.status = payload.status
    value.resolution_note = payload.resolution_note
    value.resolved_by = admin.user.id
    value.resolved_at = utc_now() if payload.status in {"resolved", "rejected"} else None
    GovernanceService(db).audit(
        admin.user.id,
        sorted(admin.permissions),
        "report.workflow",
        "governance_report",
        str(report_id),
        request.state.request_id,
        {"status": payload.status},
    )
    db.commit()
    return {"id": value.id, "status": value.status}


@router.get("/audit")
def audit_events(
    admin: AuditReadAdmin, db: DatabaseDependency, offset: int = 0, limit: int = 50
) -> list[dict[str, object]]:
    values = db.scalars(
        select(AuditEvent)
        .order_by(AuditEvent.occurred_at.desc())
        .offset(max(0, offset))
        .limit(min(max(1, limit), 100))
    ).all()
    return [
        {
            "id": item.id,
            "actor_id": item.actor_id,
            "action": item.action,
            "target_type": item.target_type,
            "target_id": item.target_id,
            "request_id": item.request_id,
            "safe_metadata": item.safe_metadata,
            "occurred_at": item.occurred_at,
        }
        for item in values
    ]


@router.get("/feature-flags", response_model=list[FeatureFlagRead])
def feature_flags(admin: SystemReadAdmin, db: DatabaseDependency) -> list[FeatureFlagRead]:
    values = db.scalars(select(FeatureFlag).order_by(FeatureFlag.key)).all()
    return [FeatureFlagRead.model_validate(item, from_attributes=True) for item in values]


@router.put("/feature-flags/{key}", response_model=FeatureFlagRead)
def update_feature_flag(
    key: str,
    payload: FeatureFlagUpdate,
    request: Request,
    admin: SystemManageAdmin,
    db: DatabaseDependency,
) -> FeatureFlagRead:
    value = db.get(FeatureFlag, key)
    if value is None:
        raise HTTPException(status_code=404, detail="Feature flag not found")
    if value.revision != payload.expected_revision:
        raise HTTPException(status_code=409, detail="Feature flag revision conflict")
    if payload.enabled != value.enabled and payload.confirmation != key:
        raise HTTPException(status_code=409, detail="Typed confirmation is required")
    value.enabled = payload.enabled
    value.revision += 1
    value.updated_by = admin.user.id
    value.updated_at = utc_now()
    GovernanceService(db).audit(
        admin.user.id,
        sorted(admin.permissions),
        "feature_flag.update",
        "feature_flag",
        key,
        request.state.request_id,
        {"enabled": value.enabled, "revision": value.revision},
    )
    db.commit()
    return FeatureFlagRead.model_validate(value, from_attributes=True)


@router.get("/system-health")
def system_health(admin: SystemReadAdmin, db: DatabaseDependency) -> dict[str, object]:
    db.execute(select(1)).scalar_one()
    return {
        "database": "ready",
        "latest_import": db.scalar(select(func.max(ContentImportJob.created_at))),
        "open_reports": db.scalar(
            select(func.count(GovernanceReport.id)).where(GovernanceReport.status == "open")
        ),
        "checked_at": utc_now(),
    }


@router.get("/metrics")
def request_metrics(request: Request, admin: SystemReadAdmin) -> dict[str, object]:
    return cast(RequestMetrics, request.app.state.request_metrics).snapshot()


@router.get("/resolution-review")
def resolution_review(
    admin: SourceManageAdmin, db: DatabaseDependency, offset: int = 0, limit: int = 50
) -> list[dict[str, object]]:
    values = db.scalars(
        select(MedicationResolution)
        .where(
            MedicationResolution.state.in_(
                [
                    "ambiguous",
                    "user_selection_required",
                    "no_trusted_match",
                    "provider_unavailable",
                ]
            )
        )
        .order_by(MedicationResolution.updated_at.desc())
        .offset(max(0, offset))
        .limit(min(max(1, limit), 100))
    ).all()
    return [
        {
            "id": item.id,
            "state": item.state,
            "input_origin": item.input_origin,
            "normalized_search_string": item.normalized_search_string,
            "candidate_count": len(item.candidates),
            "provider_failures": item.provider_failures,
            "updated_at": item.updated_at,
        }
        for item in values
    ]


@router.post("/resolution-review/{resolution_id}/annotate")
def annotate_resolution(
    resolution_id: UUID,
    payload: ResolutionAnnotationRequest,
    request: Request,
    admin: SourceManageAdmin,
    db: DatabaseDependency,
) -> dict[str, object]:
    value = db.get(MedicationResolution, resolution_id)
    if value is None:
        raise HTTPException(status_code=404, detail="Resolution not found")
    GovernanceService(db).audit(
        admin.user.id,
        sorted(admin.permissions),
        "medication_resolution.annotate",
        "medication_resolution",
        str(resolution_id),
        request.state.request_id,
        {
            "review_status": payload.review_status,
            "note": payload.note,
            "original_state": value.state,
            "candidate_count": len(value.candidates),
        },
    )
    db.commit()
    return {"id": value.id, "review_status": payload.review_status}


@router.get("/sources")
def sources(admin: SourceManageAdmin, db: DatabaseDependency) -> list[dict[str, object]]:
    rows = db.execute(
        select(
            MedicalFact.provider,
            MedicalFact.source_id,
            MedicalFact.source_title,
            MedicalFact.jurisdiction,
            MedicalFact.content_version,
            func.max(MedicalFact.retrieved_at),
            func.count(MedicalFact.id),
        )
        .group_by(
            MedicalFact.provider,
            MedicalFact.source_id,
            MedicalFact.source_title,
            MedicalFact.jurisdiction,
            MedicalFact.content_version,
        )
        .order_by(func.max(MedicalFact.retrieved_at).desc())
        .limit(100)
    ).all()
    return [
        {
            "provider": row[0],
            "source_id": row[1],
            "title": row[2],
            "jurisdiction": row[3],
            "version": row[4],
            "retrieved_at": row[5],
            "fact_count": row[6],
        }
        for row in rows
    ]


@router.get("/roles")
def roles(admin: SystemManageAdmin, db: DatabaseDependency) -> list[dict[str, object]]:
    values = db.scalars(select(AdminRole).order_by(AdminRole.name)).all()
    result: list[dict[str, object]] = []
    for role in values:
        permissions = db.scalars(
            select(AdminPermission.code)
            .join(
                AdminRolePermission,
                AdminRolePermission.permission_code == AdminPermission.code,
            )
            .where(AdminRolePermission.role_id == role.id)
            .order_by(AdminPermission.code)
        ).all()
        members = db.scalar(
            select(func.count(AdminMembership.user_id)).where(
                AdminMembership.role_id == role.id,
                AdminMembership.active.is_(True),
            )
        )
        result.append(
            {
                "id": role.id,
                "name": role.name,
                "permissions": permissions,
                "member_count": members,
            }
        )
    return result


@router.get("/sessions")
def sessions(admin: SystemManageAdmin, db: DatabaseDependency) -> list[dict[str, object]]:
    values = db.execute(
        select(AuthSession, User.email)
        .join(User, User.id == AuthSession.user_id)
        .where(AuthSession.audience == "mediexplain-admin")
        .order_by(AuthSession.created_at.desc())
        .limit(100)
    ).all()
    return [
        {
            "id": session.id,
            "email": email,
            "created_at": session.created_at,
            "last_used_at": session.last_used_at,
            "expires_at": session.expires_at,
            "revoked_at": session.revoked_at,
        }
        for session, email in values
    ]


@router.post("/sessions/{session_id}/revoke", status_code=204)
def revoke_session(
    session_id: UUID,
    request: Request,
    admin: SystemManageAdmin,
    db: DatabaseDependency,
) -> Response:
    value = db.get(AuthSession, session_id)
    if value is None or value.audience != "mediexplain-admin":
        raise HTTPException(status_code=404, detail="Administrative session not found")
    value.revoked_at = utc_now()
    GovernanceService(db).audit(
        admin.user.id,
        sorted(admin.permissions),
        "admin_session.revoke",
        "auth_session",
        str(session_id),
        request.state.request_id,
    )
    db.commit()
    return Response(status_code=204)


@router.get("/user-support")
def user_support(
    admin: Annotated[CurrentAdmin, Depends(require_permission("users.support_read"))],
    db: DatabaseDependency,
    offset: int = 0,
    limit: int = 50,
) -> list[dict[str, object]]:
    values = db.scalars(
        select(User)
        .order_by(User.created_at.desc())
        .offset(max(0, offset))
        .limit(min(max(1, limit), 100))
    ).all()
    return [
        {
            "id": item.id,
            "email": item.email,
            "active": item.is_active,
            "created_at": item.created_at,
            "updated_at": item.updated_at,
        }
        for item in values
    ]
