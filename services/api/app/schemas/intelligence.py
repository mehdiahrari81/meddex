from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import Field, HttpUrl, field_validator

from app.schemas.common import StrictSchema

ResolutionState = Literal[
    "unresolved",
    "searching",
    "candidates_found",
    "ambiguous",
    "user_selection_required",
    "match_confirmed",
    "external_identity_verified",
    "local_registry_match",
    "no_trusted_match",
    "provider_unavailable",
]
CacheState = Literal["current", "stale", "refreshing", "partial", "source_unavailable"]
GroundingStatus = Literal[
    "grounded",
    "partially_grounded",
    "insufficient_information",
    "unsafe_to_answer",
    "source_conflict",
    "provider_unavailable",
]


class IngredientRead(StrictSchema):
    name: str
    numerator_value: str | None = None
    numerator_unit: str | None = None
    denominator_value: str | None = None
    denominator_unit: str | None = None


class CandidateIdentifier(StrictSchema):
    type: str
    value: str
    jurisdiction: str | None = None


class MatchEvidence(StrictSchema):
    signal: str
    matched: bool
    requested: str | None = None
    candidate: str | None = None


class MedicationCandidateRead(StrictSchema):
    candidate_id: str
    canonical_name: str
    generic_name: str | None = None
    brand_name: str | None = None
    ingredients: list[IngredientRead] = Field(default_factory=list)
    strength: str | None = None
    dosage_form: str | None = None
    country: str | None = None
    provider: str
    provider_version: str
    identifiers: list[CandidateIdentifier] = Field(default_factory=list)
    evidence: list[MatchEvidence] = Field(default_factory=list)
    match_score: float = Field(ge=0, le=1)
    exact_identity: bool


class ResolutionCreate(StrictSchema):
    raw_confirmed_value: str = Field(min_length=1, max_length=500)
    input_origin: Literal["search", "prescription", "barcode", "saved"] = "search"
    strength: str | None = Field(default=None, max_length=100)
    dosage_form: str | None = Field(default=None, max_length=100)
    country: str | None = Field(default=None, min_length=2, max_length=2)
    prescription_item_id: str | None = Field(default=None, max_length=100)

    @field_validator("raw_confirmed_value")
    @classmethod
    def no_control_characters(cls, value: str) -> str:
        cleaned = " ".join(value.split())
        if any(ord(char) < 32 for char in cleaned):
            raise ValueError("Search input contains control characters")
        return cleaned


class ResolutionRead(StrictSchema):
    id: UUID
    state: ResolutionState
    normalized_search_string: str
    candidates: list[MedicationCandidateRead]
    provider_failures: list[dict[str, str]]
    medication_id: UUID | None = None


class ResolutionConfirm(StrictSchema):
    candidate_id: str = Field(min_length=1, max_length=160)


class SourceReferenceRead(StrictSchema):
    id: str
    provider: str
    title: str
    section: str
    jurisdiction: str | None = None
    language: str
    content_version: str
    retrieved_at: datetime
    source_updated_at: datetime | None = None
    url: HttpUrl


class MedicalFactRead(StrictSchema):
    id: UUID
    type: str
    content: str
    source: SourceReferenceRead
    review_status: str


class MedicationIdentityRead(StrictSchema):
    id: UUID
    canonical_display_name: str
    generic_name: str | None = None
    brand_names: list[str]
    ingredients: list[IngredientRead]
    dosage_form: str | None = None
    country: str | None = None
    identifiers: list[CandidateIdentifier]
    verification_state: str
    facts: list[MedicalFactRead]
    cache_state: CacheState
    interaction_provider_state: Literal["not_configured", "configured"]


class BarcodeResolveRequest(StrictSchema):
    value: str = Field(min_length=6, max_length=64, pattern=r"^[A-Za-z0-9.-]+$")


class AiQuestionRequest(StrictSchema):
    question: str = Field(min_length=1, max_length=1000)
    medication_id: UUID | None = None
    prescription_item_id: str | None = Field(default=None, max_length=100)
    mode: Literal["patient", "student"] = "patient"
    language: Literal["en", "ur"] = "en"

    @field_validator("question")
    @classmethod
    def nonempty_question(cls, value: str) -> str:
        normalized = " ".join(value.split())
        if not normalized:
            raise ValueError("Enter a question")
        return normalized


class AiAnswerRead(StrictSchema):
    answer: str
    answer_type: str
    grounding_status: GroundingStatus
    source_references: list[SourceReferenceRead]
    safety_classification: str
    limitations: list[str]
    follow_up_suggestions: list[str]
    referenced_prescription_items: list[str]
    referenced_medication_ids: list[UUID]
    language: str
    ai_provider_used: bool
    generation_provider: str | None = None
    generation_model: str | None = None
    provider_fallback_reason: str | None = None


class InformationReportCreate(StrictSchema):
    report_type: Literal[
        "incorrect_medication_match", "outdated_information", "confusing_explanation", "unsafe_ai"
    ]
    target_type: Literal["medication", "fact", "ai_answer"]
    target_id: str = Field(min_length=1, max_length=120)
    reason: str = Field(min_length=1, max_length=80)
    note: str | None = Field(default=None, max_length=1000)
