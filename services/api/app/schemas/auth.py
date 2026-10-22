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


class EmailMixin(StrictSchema):
    email: EmailStr

    @field_validator("email", mode="before")
    @classmethod
    def strip_email(cls, value: object) -> object:
        return value.strip() if isinstance(value, str) else value


class RegisterRequest(PasswordMixin, EmailMixin):
    email: EmailStr
    display_name: str = Field(min_length=1, max_length=120)

    @field_validator("display_name", mode="before")
    @classmethod
    def strip_name(cls, value: object) -> object:
        return value.strip() if isinstance(value, str) else value


class LoginRequest(EmailMixin):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)


class RefreshRequest(StrictSchema):
    refresh_token: str = Field(min_length=32, max_length=512)


class ForgotPasswordRequest(EmailMixin):
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
