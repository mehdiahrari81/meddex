"""Install attributed RxNorm identities without modifying patient or existing reference data."""

import json
from datetime import datetime
from pathlib import Path

from pydantic import BaseModel, ConfigDict, Field, field_validator
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import MedicationIdentifier, MedicationIdentity, MedicationProviderMapping
from app.providers.medication import normalize_search


class ReferenceRecord(BaseModel):
    model_config = ConfigDict(extra="forbid")
    rxcui: str = Field(pattern=r"^\d+$")
    name: str = Field(min_length=1, max_length=500)
    tty: str
    source_url: str

    @field_validator("tty")
    @classmethod
    def valid_type(cls, value: str) -> str:
        if value not in {"IN", "SCD"}:
            raise ValueError("Only ingredients and clinical drugs are imported")
        return value

    @field_validator("source_url")
    @classmethod
    def official_source(cls, value: str) -> str:
        if not value.startswith("https://rxnav.nlm.nih.gov/REST/rxcui/"):
            raise ValueError("RxNorm source URL required")
        return value


class ReferenceSnapshot(BaseModel):
    model_config = ConfigDict(extra="forbid")
    source: str = Field(pattern="^NLM RxNorm$")
    version: str = Field(min_length=1, max_length=120)
    retrieved_at: datetime
    records: list[ReferenceRecord] = Field(min_length=1, max_length=5000)


def import_medication_reference(db: Session, path: Path) -> dict[str, int]:
    snapshot = ReferenceSnapshot.model_validate(json.loads(path.read_text()))
    if len({row.rxcui for row in snapshot.records}) != len(snapshot.records):
        raise ValueError("Duplicate RxCUI in snapshot")
    added = 0
    for row in snapshot.records:
        mapping = db.scalar(
            select(MedicationProviderMapping).where(
                MedicationProviderMapping.provider == "rxnorm",
                MedicationProviderMapping.external_id == row.rxcui,
            )
        )
        if mapping is not None:
            continue
        identifier = db.scalar(
            select(MedicationIdentifier).where(
                MedicationIdentifier.identifier_type == "rxcui",
                MedicationIdentifier.value == row.rxcui,
            )
        )
        if identifier is not None:
            # Preserve an existing identity and only add its missing source mapping.
            identity = db.get(MedicationIdentity, identifier.medication_id)
            assert identity is not None
        else:
            identity = MedicationIdentity(
                canonical_display_name=row.name,
                normalized_name=normalize_search(row.name),
                generic_name=row.name if row.tty == "IN" else None,
                brand_names=[],
                country="US",
                verification_state="external_identity_verified",
            )
            identity.identifiers = [
                MedicationIdentifier(
                    identifier_type="rxcui", value=row.rxcui, jurisdiction="US", provider="rxnorm"
                )
            ]
            db.add(identity)
            db.flush()
        db.add(
            MedicationProviderMapping(
                medication_id=identity.id,
                provider="rxnorm",
                external_id=row.rxcui,
                provider_version=snapshot.version,
                verified_at=snapshot.retrieved_at,
                evidence={
                    "source_url": row.source_url,
                    "retrieved_at": snapshot.retrieved_at.isoformat(),
                    "term_type": row.tty,
                    "canonical_name": row.name,
                },
            )
        )
        added += 1
    db.commit()
    return {"added": added, "preserved": len(snapshot.records) - added}
