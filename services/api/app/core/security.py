import hashlib
import secrets
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

import jwt
from pwdlib import PasswordHash

from app.core.config import Settings
from app.core.errors import SessionExpiredError

_password_hash = PasswordHash.recommended()


def hash_password(password: str) -> str:
    return _password_hash.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    return _password_hash.verify(password, password_hash)


def hash_opaque_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def new_opaque_token(identifier: UUID | None = None) -> tuple[UUID, str, str]:
    token_id = identifier or uuid4()
    token = f"{token_id}.{secrets.token_urlsafe(48)}"
    return token_id, token, hash_opaque_token(token)


def token_identifier(token: str) -> UUID:
    try:
        return UUID(token.split(".", maxsplit=1)[0])
    except (ValueError, IndexError) as error:
        raise SessionExpiredError from error


@dataclass(frozen=True)
class AccessClaims:
    user_id: UUID
    session_id: UUID


def create_access_token(
    *,
    user_id: UUID,
    session_id: UUID,
    settings: Settings,
    now: datetime,
    audience: str = "mediexplain-mobile",
    lifetime_minutes: int | None = None,
) -> tuple[str, datetime]:
    expires_at = now + timedelta(minutes=lifetime_minutes or settings.access_token_minutes)
    payload = {
        "sub": str(user_id),
        "sid": str(session_id),
        "jti": str(uuid4()),
        "type": "access",
        "iss": "mediexplain-api",
        "aud": audience,
        "iat": now,
        "exp": expires_at,
    }
    token = jwt.encode(payload, settings.secret_key, algorithm="HS256")
    return token, expires_at


def decode_access_token(
    token: str,
    settings: Settings,
    *,
    audience: str = "mediexplain-mobile",
) -> AccessClaims:
    try:
        payload = jwt.decode(
            token,
            settings.secret_key,
            algorithms=["HS256"],
            issuer="mediexplain-api",
            audience=audience,
        )
        if payload.get("type") != "access":
            raise SessionExpiredError
        return AccessClaims(user_id=UUID(payload["sub"]), session_id=UUID(payload["sid"]))
    except (jwt.PyJWTError, KeyError, TypeError, ValueError) as error:
        raise SessionExpiredError from error


def ensure_utc(value: datetime) -> datetime:
    return value.replace(tzinfo=UTC) if value.tzinfo is None else value.astimezone(UTC)
