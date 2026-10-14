import base64
import hmac
import struct
import time
from datetime import timedelta

from cryptography.fernet import Fernet, InvalidToken
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.core.security import create_access_token, new_opaque_token, verify_password
from app.core.time import utc_now
from app.models import (
    AdminMembership,
    AdminPermission,
    AdminRole,
    AdminRolePermission,
    AuthSession,
    User,
)


class AdminAuthService:
    def __init__(self, db: Session, settings: Settings):
        self.db = db
        self.settings = settings

    def login(self, email: str, password: str, mfa_code: str | None) -> dict[str, object]:
        row = self.db.execute(
            select(User, AdminMembership, AdminRole)
            .join(AdminMembership, AdminMembership.user_id == User.id)
            .join(AdminRole, AdminRole.id == AdminMembership.role_id)
            .where(User.email == email.strip().lower(), AdminMembership.active.is_(True))
        ).one_or_none()
        if (
            row is None
            or not row[0].is_active
            or not verify_password(password, row[0].password_hash)
        ):
            raise ValueError("invalid_admin_credentials")
        user, membership, role = row
        if self.settings.admin_mfa_required and not membership.mfa_enabled:
            raise PermissionError("mfa_not_enrolled")
        if membership.mfa_enabled and (
            membership.mfa_secret_encrypted is None
            or not self._verify_totp(
                self._decrypt_mfa_secret(membership.mfa_secret_encrypted), mfa_code or ""
            )
        ):
            raise ValueError("invalid_mfa_code")
        permissions = self.db.scalars(
            select(AdminPermission.code)
            .join(AdminRolePermission, AdminRolePermission.permission_code == AdminPermission.code)
            .where(AdminRolePermission.role_id == role.id)
        ).all()
        now = utc_now()
        session_id, _, session_hash = new_opaque_token()
        auth_session = AuthSession(
            id=session_id,
            user_id=user.id,
            refresh_token_hash=session_hash,
            audience="mediexplain-admin",
            created_at=now,
            last_used_at=now,
            expires_at=now + timedelta(minutes=self.settings.admin_session_minutes),
        )
        self.db.add(auth_session)
        token, expires = create_access_token(
            user_id=user.id,
            session_id=session_id,
            settings=self.settings,
            now=now,
            audience="mediexplain-admin",
            lifetime_minutes=self.settings.admin_session_minutes,
        )
        self.db.commit()
        return {
            "session_id": session_id,
            "access_token": token,
            "access_token_expires_at": expires,
            "permissions": list(permissions),
            "role": role.name,
        }

    def encrypt_mfa_secret(self, secret: bytes) -> bytes:
        """Used by controlled provisioning; plaintext is never persisted."""
        return self._fernet().encrypt(secret)

    def _decrypt_mfa_secret(self, encrypted: bytes) -> bytes:
        try:
            return self._fernet().decrypt(encrypted)
        except InvalidToken as error:
            raise ValueError("invalid_mfa_secret") from error

    def _fernet(self) -> Fernet:
        from app.core.security import hash_opaque_token

        material = hash_opaque_token(f"{self.settings.secret_key}:admin-mfa").encode()[:32]
        return Fernet(base64.urlsafe_b64encode(material))

    @staticmethod
    def _verify_totp(secret: bytes, value: str) -> bool:
        import hashlib

        if len(value) != 6 or not value.isdigit():
            return False
        counter = int(time.time()) // 30
        for offset in (-1, 0, 1):
            digest = hmac.new(secret, struct.pack(">Q", counter + offset), hashlib.sha1).digest()
            index = digest[-1] & 0x0F
            number = (struct.unpack(">I", digest[index : index + 4])[0] & 0x7FFFFFFF) % 1_000_000
            if hmac.compare_digest(f"{number:06d}", value):
                return True
        return False
