from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import (
    JSON,
    Boolean,
    CheckConstraint,
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    LargeBinary,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.time import utc_now
from app.db.base import Base


class MedicationIdentity(Base):
    __tablename__ = "medication_identities"
    __table_args__ = (
        Index("ix_medication_identity_name_country", "normalized_name", "country"),
        Index(
            "ix_medication_identity_fuzzy_name",
            "normalized_name",
            postgresql_using="gin",
            postgresql_ops={"normalized_name": "gin_trgm_ops"},
        ).ddl_if(dialect="postgresql"),
        CheckConstraint(
            "verification_state IN ('external_identity_verified',"
            "'local_registry_match','manual_reviewed')",
            name="ck_medication_identity_verification_state",
        ),
    )

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    canonical_display_name: Mapped[str] = mapped_column(String(500))
    normalized_name: Mapped[str] = mapped_column(String(500), index=True)
    generic_name: Mapped[str | None] = mapped_column(String(500))
    brand_names: Mapped[list[str]] = mapped_column(JSON, default=list)
    dosage_form: Mapped[str | None] = mapped_column(String(200))
    country: Mapped[str | None] = mapped_column(String(2), index=True)
    verification_state: Mapped[str] = mapped_column(String(40), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)

    ingredients: Mapped[list["MedicationIngredient"]] = relationship(
        back_populates="medication", cascade="all, delete-orphan"
    )
    identifiers: Mapped[list["MedicationIdentifier"]] = relationship(
        back_populates="medication", cascade="all, delete-orphan"
    )
    mappings: Mapped[list["MedicationProviderMapping"]] = relationship(
        back_populates="medication", cascade="all, delete-orphan"
    )
    facts: Mapped[list["MedicalFact"]] = relationship(
        back_populates="medication", cascade="all, delete-orphan"
    )


class MedicationIngredient(Base):
    __tablename__ = "medication_ingredients"

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    medication_id: Mapped[UUID] = mapped_column(
        ForeignKey("medication_identities.id", ondelete="CASCADE"), index=True
    )
    name: Mapped[str] = mapped_column(String(300))
    normalized_name: Mapped[str] = mapped_column(String(300))
    numerator_value: Mapped[str | None] = mapped_column(String(80))
    numerator_unit: Mapped[str | None] = mapped_column(String(80))
    denominator_value: Mapped[str | None] = mapped_column(String(80))
    denominator_unit: Mapped[str | None] = mapped_column(String(80))
    position: Mapped[int] = mapped_column(Integer)

    medication: Mapped[MedicationIdentity] = relationship(back_populates="ingredients")


class MedicationIdentifier(Base):
    __tablename__ = "medication_identifiers"
    __table_args__ = (
        UniqueConstraint(
            "identifier_type", "value", "jurisdiction", name="uq_medication_identifier"
        ),
    )

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    medication_id: Mapped[UUID] = mapped_column(
        ForeignKey("medication_identities.id", ondelete="CASCADE"), index=True
    )
    identifier_type: Mapped[str] = mapped_column(String(40), index=True)
    value: Mapped[str] = mapped_column(String(300), index=True)
    jurisdiction: Mapped[str | None] = mapped_column(String(20))
    provider: Mapped[str] = mapped_column(String(80))

    medication: Mapped[MedicationIdentity] = relationship(back_populates="identifiers")


class MedicationProviderMapping(Base):
    __tablename__ = "medication_provider_mappings"
    __table_args__ = (
        UniqueConstraint("provider", "external_id", name="uq_medication_provider_mapping"),
    )

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    medication_id: Mapped[UUID] = mapped_column(
        ForeignKey("medication_identities.id", ondelete="CASCADE"), index=True
    )
    provider: Mapped[str] = mapped_column(String(80), index=True)
    external_id: Mapped[str] = mapped_column(String(300))
    provider_version: Mapped[str] = mapped_column(String(120))
    evidence: Mapped[dict[str, object]] = mapped_column(JSON, default=dict)
    verified_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)

    medication: Mapped[MedicationIdentity] = relationship(back_populates="mappings")


class MedicalFact(Base):
    __tablename__ = "medical_facts"
    __table_args__ = (
        UniqueConstraint(
            "medication_id",
            "provider",
            "source_id",
            "fact_type",
            "content_hash",
            name="uq_medical_fact_version",
        ),
        Index("ix_medical_fact_retrieval", "medication_id", "fact_type", "review_status"),
    )

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    medication_id: Mapped[UUID] = mapped_column(
        ForeignKey("medication_identities.id", ondelete="CASCADE"), index=True
    )
    fact_type: Mapped[str] = mapped_column(String(80), index=True)
    content: Mapped[str] = mapped_column(Text)
    provider: Mapped[str] = mapped_column(String(80), index=True)
    source_id: Mapped[str] = mapped_column(String(300))
    source_title: Mapped[str] = mapped_column(String(500))
    source_section: Mapped[str] = mapped_column(String(300))
    citation_reference: Mapped[str] = mapped_column(String(1200))
    jurisdiction: Mapped[str | None] = mapped_column(String(20))
    language: Mapped[str] = mapped_column(String(12), default="en")
    content_version: Mapped[str] = mapped_column(String(120))
    content_hash: Mapped[str] = mapped_column(String(64))
    review_status: Mapped[str] = mapped_column(String(30), default="source_retrieved")
    retrieved_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    source_updated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    medication: Mapped[MedicationIdentity] = relationship(back_populates="facts")


class ProviderCacheEntry(Base):
    __tablename__ = "provider_cache_entries"

    cache_key: Mapped[str] = mapped_column(String(64), primary_key=True)
    provider: Mapped[str] = mapped_column(String(80), index=True)
    provider_version: Mapped[str] = mapped_column(String(120))
    payload: Mapped[dict[str, object]] = mapped_column(JSON)
    content_hash: Mapped[str] = mapped_column(String(64))
    fetched_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    last_refresh_attempt_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    refresh_error_code: Mapped[str | None] = mapped_column(String(80))


class MedicationResolution(Base):
    __tablename__ = "medication_resolutions"
    __table_args__ = (
        CheckConstraint(
            "state IN ('unresolved','searching','candidates_found','ambiguous',"
            "'user_selection_required','match_confirmed','external_identity_verified',"
            "'local_registry_match','no_trusted_match','provider_unavailable')",
            name="ck_medication_resolution_state",
        ),
        Index("ix_resolution_review_queue", "state", "updated_at"),
    )

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    input_origin: Mapped[str] = mapped_column(String(40))
    raw_confirmed_value: Mapped[str] = mapped_column(String(500))
    normalized_search_string: Mapped[str] = mapped_column(String(500))
    requested_strength: Mapped[str | None] = mapped_column(String(100))
    requested_dosage_form: Mapped[str | None] = mapped_column(String(100))
    requested_country: Mapped[str | None] = mapped_column(String(2))
    prescription_item_client_id: Mapped[str | None] = mapped_column(String(100))
    state: Mapped[str] = mapped_column(String(40), index=True)
    candidates: Mapped[list[dict[str, object]]] = mapped_column(JSON, default=list)
    provider_failures: Mapped[list[dict[str, object]]] = mapped_column(JSON, default=list)
    selected_candidate_id: Mapped[str | None] = mapped_column(String(100))
    medication_id: Mapped[UUID | None] = mapped_column(
        ForeignKey("medication_identities.id", ondelete="SET NULL"), index=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)


class SavedMedication(Base):
    __tablename__ = "saved_medications"
    __table_args__ = (UniqueConstraint("user_id", "medication_id", name="uq_saved_medication"),)

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    medication_id: Mapped[UUID] = mapped_column(
        ForeignKey("medication_identities.id", ondelete="CASCADE"), index=True
    )
    saved_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)


class AiConversation(Base):
    __tablename__ = "ai_conversations"

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    medication_id: Mapped[UUID | None] = mapped_column(
        ForeignKey("medication_identities.id", ondelete="CASCADE"), index=True
    )
    language: Mapped[str] = mapped_column(String(12))
    mode: Mapped[str] = mapped_column(String(20))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)


class AiMessage(Base):
    __tablename__ = "ai_messages"

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    conversation_id: Mapped[UUID] = mapped_column(
        ForeignKey("ai_conversations.id", ondelete="CASCADE"), index=True
    )
    role: Mapped[str] = mapped_column(String(20))
    encrypted_body: Mapped[bytes] = mapped_column(LargeBinary)
    answer_type: Mapped[str | None] = mapped_column(String(40))
    grounding_status: Mapped[str | None] = mapped_column(String(40))
    safety_classification: Mapped[str | None] = mapped_column(String(40))
    source_ids: Mapped[list[str]] = mapped_column(JSON, default=list)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)


class ProviderHealthEvent(Base):
    __tablename__ = "provider_health_events"
    __table_args__ = (Index("ix_provider_health_time", "provider", "occurred_at"),)

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    provider: Mapped[str] = mapped_column(String(80), index=True)
    operation: Mapped[str] = mapped_column(String(80))
    success: Mapped[bool] = mapped_column(Boolean)
    latency_ms: Mapped[float] = mapped_column(Float)
    safe_error_code: Mapped[str | None] = mapped_column(String(80))
    cache_status: Mapped[str | None] = mapped_column(String(30))
    circuit_state: Mapped[str] = mapped_column(String(20), default="closed")
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)


class FeatureFlag(Base):
    __tablename__ = "feature_flags"

    key: Mapped[str] = mapped_column(String(100), primary_key=True)
    enabled: Mapped[bool] = mapped_column(Boolean, default=False)
    description: Mapped[str] = mapped_column(String(500))
    revision: Mapped[int] = mapped_column(Integer, default=1)
    updated_by: Mapped[UUID | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
