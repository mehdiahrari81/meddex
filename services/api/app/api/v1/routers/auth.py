from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Body, HTTPException, status
from sqlalchemy import select

from app.api.dependencies import (
    CurrentIdentityDependency,
    DatabaseDependency,
    EmailSenderDependency,
    SettingsDependency,
)
from app.core.time import utc_now
from app.models import AuthSession
from app.schemas.auth import (
    ForgotPasswordRequest,
    LoginRequest,
    ManagedSessionRead,
    RefreshRequest,
    RegisterRequest,
    ResetPasswordRequest,
    TokenResponse,
)
from app.schemas.common import MessageResponse
from app.services.auth import AuthService

router = APIRouter(prefix="/auth", tags=["authentication"])


@router.get("/sessions", response_model=list[ManagedSessionRead])
def list_sessions(
    identity: CurrentIdentityDependency,
    db: DatabaseDependency,
) -> list[ManagedSessionRead]:
    sessions = db.scalars(
        select(AuthSession)
        .where(
            AuthSession.user_id == identity.user.id,
            AuthSession.audience == "mediexplain-mobile",
            AuthSession.revoked_at.is_(None),
            AuthSession.expires_at > utc_now(),
        )
        .order_by(AuthSession.created_at.desc())
    ).all()
    return [
        ManagedSessionRead(
            id=session.id,
            created_at=session.created_at,
            last_used_at=session.last_used_at,
            expires_at=session.expires_at,
            is_current=session.id == identity.auth_session.id,
        )
        for session in sessions
    ]


@router.delete("/sessions/{session_id}", status_code=status.HTTP_204_NO_CONTENT)
def revoke_session(
    session_id: UUID,
    identity: CurrentIdentityDependency,
    db: DatabaseDependency,
) -> None:
    session = db.scalar(
        select(AuthSession).where(
            AuthSession.id == session_id,
            AuthSession.user_id == identity.user.id,
            AuthSession.audience == "mediexplain-mobile",
        )
    )
    if session is None:
        raise HTTPException(status_code=404, detail="Session not found")
    session.revoked_at = session.revoked_at or utc_now()
    db.commit()


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
def register(
    request: RegisterRequest,
    db: DatabaseDependency,
    settings: SettingsDependency,
    email_sender: EmailSenderDependency,
) -> TokenResponse:
    return AuthService(db, settings, email_sender).register(
        str(request.email), request.password, request.display_name
    )


@router.post("/login", response_model=TokenResponse)
def login(
    request: LoginRequest,
    db: DatabaseDependency,
    settings: SettingsDependency,
    email_sender: EmailSenderDependency,
) -> TokenResponse:
    return AuthService(db, settings, email_sender).login(str(request.email), request.password)


@router.post("/refresh", response_model=TokenResponse)
def refresh(
    request: RefreshRequest,
    db: DatabaseDependency,
    settings: SettingsDependency,
    email_sender: EmailSenderDependency,
) -> TokenResponse:
    return AuthService(db, settings, email_sender).refresh(request.refresh_token)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(
    identity: CurrentIdentityDependency,
    db: DatabaseDependency,
    settings: SettingsDependency,
    email_sender: EmailSenderDependency,
) -> None:
    AuthService(db, settings, email_sender).revoke(identity.auth_session.id)


@router.post("/password/forgot", response_model=MessageResponse)
def forgot_password(
    request: ForgotPasswordRequest,
    db: DatabaseDependency,
    settings: SettingsDependency,
    email_sender: EmailSenderDependency,
) -> MessageResponse:
    AuthService(db, settings, email_sender).request_password_reset(str(request.email))
    return MessageResponse(
        message="If an account exists, the configured delivery service will process the request."
    )


@router.post("/password/reset", response_model=MessageResponse)
def reset_password(
    request: Annotated[ResetPasswordRequest, Body()],
    db: DatabaseDependency,
    settings: SettingsDependency,
    email_sender: EmailSenderDependency,
) -> MessageResponse:
    AuthService(db, settings, email_sender).reset_password(request.token, request.new_password)
    return MessageResponse(message="Password reset completed. Sign in again on all devices.")
