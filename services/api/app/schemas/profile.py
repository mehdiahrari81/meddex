from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import EmailStr, Field

from app.schemas.common import StrictSchema

UserMode = Literal["patient", "student", "guest"]
ExplanationLevel = Literal["simple", "standard", "technical"]
ThemePreference = Literal["system", "light", "dark"]


class UserRead(StrictSchema):
    id: UUID
    email: EmailStr
    display_name: str
    created_at: datetime


class ProfileRead(StrictSchema):
    user_id: UUID
    email: EmailStr
    display_name: str
    user_mode: UserMode
    explanation_level: ExplanationLevel
    preferred_language: Literal["en", "ur"]
    theme: ThemePreference
    text_scale: float
    large_controls: bool
    high_readability: bool
    reduced_motion: bool
    tts_enabled: bool
    haptics_enabled: bool
    notifications_enabled: bool
    sync_enabled: bool
    analytics_enabled: bool
    biometric_lock_enabled: bool
    account_created_at: datetime
    consent_version: int


class ProfileUpdate(StrictSchema):
    display_name: str | None = Field(default=None, min_length=1, max_length=120)
    user_mode: UserMode | None = None
    explanation_level: ExplanationLevel | None = None
    preferred_language: Literal["en", "ur"] | None = None
    theme: ThemePreference | None = None
    text_scale: float | None = Field(default=None, ge=0.9, le=1.5)
    large_controls: bool | None = None
    high_readability: bool | None = None
    reduced_motion: bool | None = None
    tts_enabled: bool | None = None
    haptics_enabled: bool | None = None
    notifications_enabled: bool | None = None
    sync_enabled: bool | None = None
    analytics_enabled: bool | None = None
    biometric_lock_enabled: bool | None = None
