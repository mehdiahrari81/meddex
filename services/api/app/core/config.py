from functools import lru_cache
from typing import Literal

from pydantic import EmailStr, Field, SecretStr, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_prefix="MEDIEXPLAIN_",
        extra="ignore",
    )

    app_name: str = "MediExplain API"
    environment: Literal["development", "testing", "production"] = "development"
    api_prefix: str = "/api/v1"
    database_url: str = "postgresql+psycopg://mediexplain:change-me@localhost:5432/mediexplain"
    secret_key: str = "development-only-secret-change-before-production"
    allowed_origins: list[str] = Field(default_factory=lambda: ["http://localhost:3000"])
    log_level: str = "INFO"
    access_token_minutes: int = 15
    refresh_token_days: int = 30
    password_reset_minutes: int = 30
    smtp_host: str | None = None
    smtp_port: int = Field(default=587, ge=1, le=65535)
    smtp_security: Literal["none", "starttls", "ssl"] = "starttls"
    smtp_username: str | None = None
    smtp_password: SecretStr | None = None
    smtp_sender: EmailStr = "noreply@example.com"
    smtp_timeout_seconds: float = Field(default=8.0, gt=0, le=30)
    rate_limit_per_minute: int = 100
    consent_version: int = 1
    provider_timeout_seconds: float = 8.0
    provider_retry_count: int = 1
    rxnorm_enabled: bool = True
    medlineplus_enabled: bool = True
    dailymed_enabled: bool = True
    drap_dataset_enabled: bool = True
    interaction_provider: Literal["not_configured"] = "not_configured"
    ai_provider: Literal["disabled", "openai_compatible", "ollama"] = "disabled"
    ai_base_url: str | None = None
    ai_api_key: str | None = None
    ai_model: str | None = None
    ai_timeout_seconds: float = Field(default=60.0, gt=0, le=120)
    admin_session_minutes: int = 30
    admin_inactivity_minutes: int = 15
    admin_mfa_required: bool = False
    max_import_bytes: int = 5_000_000
    temporary_scan_retention_hours: int = 24
    ai_conversation_retention_days: int = 30
    export_retention_hours: int = 24
    provider_cache_retention_days: int = 90

    @field_validator("allowed_origins")
    @classmethod
    def origins_must_be_explicit(cls, value: list[str]) -> list[str]:
        if "*" in value:
            raise ValueError("Wildcard CORS origins are not allowed")
        return value

    @model_validator(mode="after")
    def validate_production_security(self) -> "Settings":
        if bool(self.smtp_username) != bool(self.smtp_password):
            raise ValueError("SMTP username and password must be configured together")
        if self.environment == "production":
            if self.smtp_host and self.smtp_security == "none":
                raise ValueError("Production email delivery requires TLS")
            if len(self.secret_key) < 32 or "change" in self.secret_key.lower():
                raise ValueError("Production secret key must be a strong external secret")
            if not self.database_url.startswith("postgresql+"):
                raise ValueError("Production database must use PostgreSQL")
            if not self.admin_mfa_required:
                raise ValueError("Production admin access requires MFA")
            if self.ai_provider != "disabled":
                if not self.ai_base_url or not self.ai_model:
                    raise ValueError("Configured AI provider requires base URL and model")
                if self.ai_provider == "openai_compatible" and not self.ai_api_key:
                    raise ValueError("Hosted AI provider key must be supplied server-side")
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()
