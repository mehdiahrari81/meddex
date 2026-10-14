from typing import Literal, cast

from sqlalchemy.orm import Session

from app.core.errors import AppException, ConflictError
from app.core.time import utc_now
from app.models import ConsentRecord, User
from app.repositories.users import ConsentRepository
from app.schemas.consent import ConsentCreate
from app.schemas.profile import (
    ExplanationLevel,
    ProfileRead,
    ProfileUpdate,
    ThemePreference,
    UserMode,
)


class ProfileService:
    def __init__(self, db: Session) -> None:
        self.db = db

    def read(self, user: User) -> ProfileRead:
        profile = user.profile
        return ProfileRead(
            user_id=user.id,
            email=user.email,
            display_name=profile.display_name,
            user_mode=cast(UserMode, profile.user_mode),
            explanation_level=cast(ExplanationLevel, profile.explanation_level),
            preferred_language=cast("Literal['en', 'ur']", profile.preferred_language),
            theme=cast(ThemePreference, profile.theme),
            text_scale=profile.text_scale,
            large_controls=profile.large_controls,
            high_readability=profile.high_readability,
            reduced_motion=profile.reduced_motion,
            tts_enabled=profile.tts_enabled,
            haptics_enabled=profile.haptics_enabled,
            notifications_enabled=profile.notifications_enabled,
            sync_enabled=profile.sync_enabled,
            analytics_enabled=profile.analytics_enabled,
            biometric_lock_enabled=profile.biometric_lock_enabled,
            account_created_at=user.created_at,
            consent_version=profile.consent_version,
        )

    def update(self, user: User, changes: ProfileUpdate) -> ProfileRead:
        for field, value in changes.model_dump(exclude_unset=True).items():
            if value is not None:
                setattr(user.profile, field, value)
        self.db.commit()
        return self.read(user)

    def record_consent(self, user: User, consent: ConsentCreate) -> ConsentRecord:
        repository = ConsentRepository(self.db)
        existing = repository.by_user_and_version(user.id, consent.version)
        if existing is not None:
            raise ConflictError("consent_exists", "This consent version is already recorded.")
        record = ConsentRecord(
            user_id=user.id,
            version=consent.version,
            locale=consent.locale,
            accepted_at=utc_now(),
        )
        self.db.add(record)
        if consent.version > user.profile.consent_version:
            user.profile.consent_version = consent.version
        self.db.commit()
        self.db.refresh(record)
        return record

    def delete_account(self, user: User) -> None:
        if not user.is_active:
            raise AppException(
                "account_inactive", "The account is already inactive.", status_code=409
            )
        self.db.delete(user)
        self.db.commit()
