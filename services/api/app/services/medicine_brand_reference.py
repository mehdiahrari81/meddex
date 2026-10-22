"""Attributed brand-to-ingredient references; never product or dose equivalence."""

import json
from datetime import datetime
from pathlib import Path
from uuid import NAMESPACE_URL, uuid5

from pydantic import BaseModel, ConfigDict, Field, HttpUrl
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import MedicationIdentity, MedicationProviderMapping
from app.providers.medication import normalize_search
from app.schemas.intelligence import SourceReferenceRead


class BrandReference(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    brand: str
    ingredient: str
    rxcui: str = Field(pattern=r"^\d+$")
    title: str
    url: HttpUrl
    jurisdiction: str
    verified_at: datetime

    def citation(self, version: str) -> SourceReferenceRead:
        return SourceReferenceRead(
            id=str(uuid5(NAMESPACE_URL, str(self.url))),
            provider="verified_brand_reference",
            title=self.title,
            section="Brand and ingredient identity only",
            jurisdiction=self.jurisdiction,
            language="en",
            content_version=version,
            retrieved_at=self.verified_at,
            url=self.url,
        )


def lookup_brand(name: str) -> tuple[BrandReference, str] | None:
    path = Path(__file__).resolve().parents[1] / "reference/medicine_brands.json"
    data = json.loads(path.read_text())
    for row in data["records"]:
        record = BrandReference.model_validate_json(json.dumps(row))
        if normalize_search(record.brand) == normalize_search(name):
            return record, str(data["version"])
    return None


def cache_brand_reference(
    db: Session, medicine: MedicationIdentity, reference: BrandReference, version: str
) -> None:
    key = normalize_search(reference.brand)
    existing = db.scalar(
        select(MedicationProviderMapping).where(
            MedicationProviderMapping.provider == "verified_brand_reference",
            MedicationProviderMapping.external_id == key,
        )
    )
    if existing is None:
        db.add(
            MedicationProviderMapping(
                medication_id=medicine.id,
                provider="verified_brand_reference",
                external_id=key,
                provider_version=version,
                verified_at=reference.verified_at,
                evidence=reference.model_dump(mode="json")
                | {"scope": "ingredient_information_only"},
            )
        )
        db.commit()
