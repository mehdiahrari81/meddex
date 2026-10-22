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
    local_server_private_key: SecretStr | None = None
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
    ai_provider: Literal["disabled", "openai_compatible", "ollama", "gemini_ollama"] = (
        "gemini_ollama"
    )
    ai_base_url: str | None = None
    ai_api_key: str | None = None
    ai_model: str | None = None
    ai_timeout_seconds: float = Field(default=60.0, gt=0, le=120)
    gemini_api_key: SecretStr | None = None
    gemini_model: str = Field(default="gemini-3.5-flash-lite", pattern=r"^[A-Za-z0-9_.-]{1,100}$")
    gemini_fallback_model: str = Field(
        default="gemini-3.1-flash-lite", pattern=r"^[A-Za-z0-9_.-]{1,100}$"
    )
    # Empty until an emergency model passes the deployment's live API checks.
    gemini_emergency_model: str = Field(default="", pattern=r"^[A-Za-z0-9_.-]{0,100}$")
    gemini_prescription_model: str = Field(
        default="gemini-3.5-flash-lite", pattern=r"^[A-Za-z0-9_.-]{1,100}$"
    )
    gemini_handwriting_model: str = Field(
        default="gemini-3.5-flash-lite", pattern=r"^[A-Za-z0-9_.-]{1,100}$"
    )
    gemini_prescription_fallback_model: str = Field(
        default="gemini-3.1-flash-lite", pattern=r"^[A-Za-z0-9_.-]{1,100}$"
    )
    gemini_handwriting_fallback_model: str = Field(
        default="gemini-3.1-flash-lite", pattern=r"^[A-Za-z0-9_.-]{1,100}$"
    )
    gemini_prescription_emergency_model: str = Field(default="", pattern=r"^[A-Za-z0-9_.-]{0,100}$")
    gemini_handwriting_emergency_model: str = Field(default="", pattern=r"^[A-Za-z0-9_.-]{0,100}$")
    gemini_handwriting_recheck: bool = True
    gemini_timeout_seconds: float = Field(default=20, gt=0, le=30)
    gemini_cooldown_seconds: float = Field(default=300, ge=1, le=86400)
    groq_api_key: SecretStr | None = None
    groq_model: str = Field(default="openai/gpt-oss-120b", pattern=r"^[A-Za-z0-9_./-]{1,100}$")
    groq_vision_model: str = Field(default="qwen/qwen3.8-27b", pattern=r"^[A-Za-z0-9_./-]{1,100}$")
    groq_timeout_seconds: float = Field(default=20, gt=0, le=30)
    groq_cooldown_seconds: float = Field(default=300, ge=1, le=86400)
    groq_max_output_tokens: int = Field(default=2048, ge=512, le=8192)
    groq_batch_max_output_tokens: int = Field(default=8192, ge=512, le=8192)
    groq_vision_max_output_tokens: int = Field(default=768, ge=256, le=8192)
    groq_vision_max_images: int = Field(default=3, ge=1, le=3)
    ollama_base_url: str = "http://127.0.0.1:11434"
    ollama_model: str = "qwen3:1.7b"
    admin_session_minutes: int = 30
    admin_inactivity_minutes: int = 15
    admin_allow_local_self_review: bool = False
    admin_mfa_required: bool = False
    max_import_bytes: int = 5_000_000
    temporary_scan_retention_hours: int = 24
    ai_conversation_retention_days: int = 30
    export_retention_hours: int = 24
    provider_cache_retention_days: int = 90

    @field_validator("local_server_private_key")
    @classmethod
    def valid_local_server_key(cls, value: SecretStr | None) -> SecretStr | None:
        if value is not None:
            raw = value.get_secret_value()
            try:
                number = int(raw, 16)
            except ValueError:
                raise ValueError(
                    "Local server identity must be a valid P-256 private key"
                ) from None
            order = 0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551
            if len(raw) != 64 or not 0 < number < order:
                raise ValueError("Local server identity must be a valid P-256 private key")
        return value

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
            if self.admin_allow_local_self_review:
                raise ValueError("Single-admin self-review is development-only")
            if self.smtp_host and self.smtp_security == "none":
                raise ValueError("Production email delivery requires TLS")
            if len(self.secret_key) < 32 or "change" in self.secret_key.lower():
                raise ValueError("Production secret key must be a strong external secret")
            if not self.database_url.startswith("postgresql+"):
                raise ValueError("Production database must use PostgreSQL")
            if not self.admin_mfa_required:
                raise ValueError("Production admin access requires MFA")
            if self.ai_provider in {"openai_compatible", "ollama"}:
                if not self.ai_base_url or not self.ai_model:
                    raise ValueError("Configured AI provider requires base URL and model")
                if self.ai_provider == "openai_compatible" and not self.ai_api_key:
                    raise ValueError("Hosted AI provider key must be supplied server-side")
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()
