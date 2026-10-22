from collections.abc import Callable
from dataclasses import dataclass
from datetime import timedelta
from typing import Annotated, cast

from fastapi import Depends, HTTPException, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.core.errors import SessionExpiredError
from app.core.security import decode_access_token, ensure_utc
from app.core.time import utc_now
from app.db.session import get_db
from app.models import (
    AdminMembership,
    AdminPermission,
    AdminRole,
    AdminRolePermission,
    AuthSession,
    User,
)
from app.repositories.users import SessionRepository, UserRepository
from app.services.email import EmailSender

bearer = HTTPBearer(auto_error=False)


def get_app_settings(request: Request) -> Settings:
    return cast(Settings, request.app.state.settings)


def get_email_sender(request: Request) -> EmailSender:
    return cast(EmailSender, request.app.state.email_sender)


@dataclass(frozen=True)
class CurrentIdentity:
    user: User
    auth_session: AuthSession


def current_identity(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)],
    db: Annotated[Session, Depends(get_db)],
    settings: Annotated[Settings, Depends(get_app_settings)],
) -> CurrentIdentity:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise SessionExpiredError
    claims = decode_access_token(credentials.credentials, settings)
    auth_session = SessionRepository(db).by_id(claims.session_id)
    if (
        auth_session is None
        or auth_session.audience != "mediexplain-mobile"
        or auth_session.user_id != claims.user_id
        or auth_session.revoked_at is not None
        or ensure_utc(auth_session.expires_at) <= utc_now()
    ):
        raise SessionExpiredError
    user = UserRepository(db).by_id(claims.user_id)
    if user is None or not user.is_active:
        raise SessionExpiredError
    return CurrentIdentity(user=user, auth_session=auth_session)


CurrentIdentityDependency = Annotated[CurrentIdentity, Depends(current_identity)]
DatabaseDependency = Annotated[Session, Depends(get_db)]
SettingsDependency = Annotated[Settings, Depends(get_app_settings)]
EmailSenderDependency = Annotated[EmailSender, Depends(get_email_sender)]


@dataclass(frozen=True)
class CurrentAdmin:
    user: User
    auth_session: AuthSession
    role: str
    permissions: frozenset[str]


def current_admin(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)],
    db: Annotated[Session, Depends(get_db)],
    settings: Annotated[Settings, Depends(get_app_settings)],
) -> CurrentAdmin:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise SessionExpiredError
    claims = decode_access_token(credentials.credentials, settings, audience="mediexplain-admin")
    auth_session = SessionRepository(db).by_id(claims.session_id)
    if (
        auth_session is None
        or auth_session.audience != "mediexplain-admin"
        or auth_session.user_id != claims.user_id
        or auth_session.revoked_at is not None
        or ensure_utc(auth_session.expires_at) <= utc_now()
    ):
        raise SessionExpiredError
    now = utc_now()
    if ensure_utc(auth_session.last_used_at) <= now - timedelta(
        minutes=settings.admin_inactivity_minutes
    ):
        auth_session.revoked_at = now
        db.commit()
        raise SessionExpiredError
    row = db.execute(
        select(AdminMembership, AdminRole)
        .join(AdminRole, AdminMembership.role_id == AdminRole.id)
        .where(AdminMembership.user_id == claims.user_id, AdminMembership.active.is_(True))
    ).one_or_none()
    if row is None:
        raise HTTPException(status_code=403, detail="Administrative access is not granted")
    membership, role = row
    if settings.admin_mfa_required and not membership.mfa_enabled:
        raise HTTPException(status_code=403, detail="Administrative MFA is required")
    permissions = frozenset(
        db.scalars(
            select(AdminPermission.code)
            .join(
                AdminRolePermission,
                AdminRolePermission.permission_code == AdminPermission.code,
            )
            .where(AdminRolePermission.role_id == role.id)
        ).all()
    )
    user = UserRepository(db).by_id(claims.user_id)
    if user is None or not user.is_active:
        raise SessionExpiredError
    auth_session.last_used_at = now
    db.commit()
    return CurrentAdmin(user, auth_session, role.name, permissions)


CurrentAdminDependency = Annotated[CurrentAdmin, Depends(current_admin)]


def require_permission(permission: str) -> Callable[[CurrentAdmin], CurrentAdmin]:
    def dependency(admin: CurrentAdminDependency) -> CurrentAdmin:
        if permission not in admin.permissions:
            raise HTTPException(status_code=403, detail="Permission denied")
        return admin

    return dependency
