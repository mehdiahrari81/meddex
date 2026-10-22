import secrets
from datetime import timedelta
from uuid import UUID, uuid4

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.core.errors import ConflictError, InvalidCredentialsError, SessionExpiredError
from app.core.security import (
    create_access_token,
    ensure_utc,
    hash_opaque_token,
    hash_password,
    new_opaque_token,
    token_identifier,
    verify_password,
)
from app.core.time import utc_now
from app.models import AuthSession, PasswordResetToken, User, UserProfile
from app.repositories.users import PasswordResetRepository, SessionRepository, UserRepository
from app.schemas.auth import TokenResponse
from app.services.email import EmailSender

_DUMMY_PASSWORD_HASH = hash_password("TimingOnlyPassword!123")


class AuthService:
    def __init__(self, db: Session, settings: Settings, email_sender: EmailSender) -> None:
        self.db = db
        self.settings = settings
        self.email_sender = email_sender
        self.users = UserRepository(db)
        self.sessions = SessionRepository(db)
        self.password_resets = PasswordResetRepository(db)

    def register(self, email: str, password: str, display_name: str) -> TokenResponse:
        normalized_email = email.strip().lower()
        if self.users.by_email(normalized_email) is not None:
            raise ConflictError("email_exists", "An account with this email already exists.")
        user = User(
            email=normalized_email,
            password_hash=hash_password(password),
            profile=UserProfile(display_name=display_name.strip()),
        )
        self.users.add(user)
        try:
            self.db.flush()
        except IntegrityError as error:
            self.db.rollback()
            raise ConflictError(
                "email_exists", "An account with this email already exists."
            ) from error
        return self._issue_session(user)

    def login(self, email: str, password: str) -> TokenResponse:
        user = self.users.by_email(email.strip().lower())
        candidate_hash = user.password_hash if user is not None else _DUMMY_PASSWORD_HASH
        password_matches = verify_password(password, candidate_hash)
        if user is None or not password_matches or not user.is_active:
            raise InvalidCredentialsError
        return self._issue_session(user)

    def _issue_session(self, user: User) -> TokenResponse:
        now = utc_now()
        session_id = uuid4()
        _, refresh_token, refresh_hash = new_opaque_token(session_id)
        auth_session = AuthSession(
            id=session_id,
            user_id=user.id,
            refresh_token_hash=refresh_hash,
            created_at=now,
            last_used_at=now,
            expires_at=now + timedelta(days=self.settings.refresh_token_days),
        )
        self.sessions.add(auth_session)
        access_token, access_expires = create_access_token(
            user_id=user.id,
            session_id=session_id,
            settings=self.settings,
            now=now,
        )
        self.db.commit()
        return TokenResponse(
            session_id=session_id,
            user_id=user.id,
            access_token=access_token,
            refresh_token=refresh_token,
            access_token_expires_at=access_expires,
            created_at=now,
        )

    def refresh(self, refresh_token: str) -> TokenResponse:
        session_id = token_identifier(refresh_token)
        auth_session = self.db.scalar(
            select(AuthSession).where(AuthSession.id == session_id).with_for_update()
        )
        now = utc_now()
        if auth_session is None or auth_session.audience != "mediexplain-mobile":
            raise SessionExpiredError
        if not secrets.compare_digest(
            auth_session.refresh_token_hash, hash_opaque_token(refresh_token)
        ):
            auth_session.revoked_at = now
            self.db.commit()
            raise SessionExpiredError
        if auth_session.revoked_at is not None or ensure_utc(auth_session.expires_at) <= now:
            raise SessionExpiredError
        user = self.users.by_id(auth_session.user_id)
        if user is None or not user.is_active:
            raise SessionExpiredError

        _, rotated_refresh, rotated_hash = new_opaque_token(auth_session.id)
        auth_session.refresh_token_hash = rotated_hash
        auth_session.last_used_at = now
        access_token, access_expires = create_access_token(
            user_id=user.id,
            session_id=auth_session.id,
            settings=self.settings,
            now=now,
        )
        self.db.commit()
        return TokenResponse(
            session_id=auth_session.id,
            user_id=user.id,
            access_token=access_token,
            refresh_token=rotated_refresh,
            access_token_expires_at=access_expires,
            created_at=auth_session.created_at,
        )

    def revoke(self, session_id: UUID) -> None:
        auth_session = self.sessions.by_id(session_id)
        if auth_session is not None and auth_session.revoked_at is None:
            auth_session.revoked_at = utc_now()
            self.db.commit()

    def request_password_reset(self, email: str) -> None:
        user = self.users.by_email(email.strip().lower())
        if user is None or not user.is_active:
            return
        now = utc_now()
        token_id, token, token_hash = new_opaque_token()
        self.db.add(
            PasswordResetToken(
                id=token_id,
                user_id=user.id,
                token_hash=token_hash,
                created_at=now,
                expires_at=now + timedelta(minutes=self.settings.password_reset_minutes),
            )
        )
        self.db.commit()
        self.email_sender.send_password_reset(user.email, token)

    def reset_password(self, token: str, new_password: str) -> None:
        token_id = token_identifier(token)
        record = self.password_resets.by_id(token_id)
        now = utc_now()
        if (
            record is None
            or record.used_at is not None
            or ensure_utc(record.expires_at) <= now
            or not secrets.compare_digest(record.token_hash, hash_opaque_token(token))
        ):
            raise SessionExpiredError
        user = self.users.by_id(record.user_id)
        if user is None or not user.is_active:
            raise SessionExpiredError
        user.password_hash = hash_password(new_password)
        record.used_at = now
        for auth_session in user.sessions:
            if auth_session.revoked_at is None:
                auth_session.revoked_at = now
        self.db.commit()
