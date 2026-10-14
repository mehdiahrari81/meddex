from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import Field, field_validator, model_validator

from app.schemas.common import StrictSchema

PipelineState = Literal[
    "userReviewRequired",
    "userConfirmed",
    "readyForMedicationLookup",
]
ItemState = Literal[
    "detected",
    "needsReview",
    "edited",
    "confirmedByUser",
    "unresolved",
    "rejected",
    "readyForLookup",
]
FieldType = Literal[
    "medicationName",
    "strength",
    "dosageForm",
    "dose",
    "route",
    "frequency",
    "duration",
    "instructions",
]


class PrescriptionFieldPayload(StrictSchema):
    type: FieldType
    original_value: str | None = Field(default=None, max_length=500)
    machine_normalized_value: str | None = Field(default=None, max_length=500)
    current_value: str | None = Field(default=None, max_length=500)
    source: Literal["ocr", "parser", "systemSuggestion", "user"]
    confidence: Literal["unknown", "low", "medium", "high"]
    ambiguous: bool
    user_confirmed: bool
    changed_at: datetime | None = None
    possible_meanings: list[str] = Field(default_factory=list, max_length=20)


class PrescriptionItemPayload(StrictSchema):
    id: str = Field(min_length=1, max_length=100)
    state: ItemState
    page_number: int = Field(ge=0, le=100)
    position: int = Field(ge=0, le=1000)
    fields: list[PrescriptionFieldPayload] = Field(default_factory=list, max_length=20)

    @model_validator(mode="after")
    def confirmed_identity_is_explicit(self) -> "PrescriptionItemPayload":
        if self.state not in {"confirmedByUser", "readyForLookup"}:
            return self
        identity = next((item for item in self.fields if item.type == "medicationName"), None)
        if (
            identity is None
            or not identity.current_value
            or not identity.user_confirmed
            or identity.ambiguous
        ):
            raise ValueError("confirmed item requires an explicit, unambiguous medicine name")
        return self


class PrescriptionCreate(StrictSchema):
    id: str = Field(min_length=1, max_length=100)
    source_type: Literal["camera", "gallery", "fileImport", "documentScanner", "userEntered"]
    capture_date: datetime
    parser_version: str = Field(min_length=1, max_length=80)
    ocr_provider: str | None = Field(default=None, max_length=100)
    ocr_provider_version: str | None = Field(default=None, max_length=80)
    page_count: int = Field(ge=0, le=100)
    verification_state: PipelineState
    user_confirmed_at: datetime | None = None
    updated_at: datetime
    items: list[PrescriptionItemPayload] = Field(default_factory=list, max_length=100)

    @field_validator("items")
    @classmethod
    def unique_item_ids(cls, value: list[PrescriptionItemPayload]) -> list[PrescriptionItemPayload]:
        ids = [item.id for item in value]
        if len(ids) != len(set(ids)):
            raise ValueError("item IDs must be unique")
        return value


class PrescriptionPatch(StrictSchema):
    revision: int = Field(ge=1)
    verification_state: PipelineState | None = None
    user_confirmed_at: datetime | None = None
    updated_at: datetime
    items: list[PrescriptionItemPayload] | None = Field(default=None, max_length=100)


class PrescriptionItemCreate(PrescriptionItemPayload):
    pass


class PrescriptionItemPatch(StrictSchema):
    state: ItemState | None = None
    page_number: int | None = Field(default=None, ge=0, le=100)
    position: int | None = Field(default=None, ge=0, le=1000)
    fields: list[PrescriptionFieldPayload] | None = Field(default=None, max_length=20)
    updated_at: datetime


class PrescriptionItemRead(PrescriptionItemPayload):
    created_at: datetime
    updated_at: datetime


class PrescriptionRead(StrictSchema):
    id: UUID
    client_id: str
    source_type: str
    capture_date: datetime
    parser_version: str
    ocr_provider: str | None
    ocr_provider_version: str | None
    page_count: int
    verification_state: str
    user_confirmed_at: datetime | None
    revision: int
    created_at: datetime
    updated_at: datetime
    items: list[PrescriptionItemRead]


class PrescriptionSummary(StrictSchema):
    id: UUID
    client_id: str
    capture_date: datetime
    verification_state: str
    item_count: int
    unresolved_count: int
    revision: int
    updated_at: datetime


class PrescriptionReportCreate(StrictSchema):
    reason: Literal["ocrError", "parserError", "privacyConcern", "other"]
    note: str | None = Field(default=None, max_length=1000)


class PrescriptionReportRead(StrictSchema):
    id: UUID
    prescription_id: UUID
    reason: str
    created_at: datetime


class BarcodeCreate(StrictSchema):
    id: str = Field(min_length=1, max_length=100)
    format: str = Field(min_length=1, max_length=50)
    raw_value: str = Field(min_length=1, max_length=500)
    source: str = Field(min_length=1, max_length=50)
    scanned_at: datetime
    user_confirmed: bool = False


class BarcodeRead(BarcodeCreate):
    server_id: UUID
