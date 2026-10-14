import re
from datetime import datetime
from uuid import UUID

from pydantic import EmailStr, Field, field_validator

from app.schemas.common import StrictSchema

PASSWORD_PATTERN = re.compile(r"^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{12,128}$")


class PasswordMixin(StrictSchema):
    password: str = Field(min_length=12, max_length=128)

    @field_validator("password")
    @classmethod
    def password_complexity(cls, value: str) -> str:
        if not PASSWORD_PATTERN.match(value):
            raise ValueError(
                "Password must include uppercase, lowercase, number, and symbol characters"
            )
        return value


class RegisterRequest(PasswordMixin):
    email: EmailStr
    display_name: str = Field(min_length=1, max_length=120)


class LoginRequest(StrictSchema):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)


class RefreshRequest(StrictSchema):
    refresh_token: str = Field(min_length=32, max_length=512)


class ForgotPasswordRequest(StrictSchema):
    email: EmailStr


class ResetPasswordRequest(StrictSchema):
    token: str = Field(min_length=32, max_length=512)
    new_password: str = Field(min_length=12, max_length=128)

    @field_validator("new_password")
    @classmethod
    def password_complexity(cls, value: str) -> str:
        if not PASSWORD_PATTERN.match(value):
            raise ValueError(
                "Password must include uppercase, lowercase, number, and symbol characters"
            )
        return value


class TokenResponse(StrictSchema):
    session_id: UUID
    user_id: UUID
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    access_token_expires_at: datetime
    created_at: datetime


class ManagedSessionRead(StrictSchema):
    id: UUID
    created_at: datetime
    last_used_at: datetime
    expires_at: datetime
    is_current: bool
