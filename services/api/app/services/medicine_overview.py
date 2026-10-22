"""General medicine information previews, independent of prescription confirmation."""

import re
from typing import Literal
from uuid import UUID

from pydantic import Field, field_validator
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.providers.medication import normalize_search
from app.schemas.common import StrictSchema
from app.schemas.intelligence import (
    AiAnswerRead,
    AiQuestionRequest,
    MedicationCandidateRead,
    SourceReferenceRead,
)
from app.services.medical_rag import MedicalRagService
from app.services.medication_intelligence import MedicationIntelligenceService
from app.services.medicine_brand_reference import cache_brand_reference, lookup_brand
from app.services.medicine_name_resolution import MedicineNameResolver


class MedicineOverviewRequest(StrictSchema):
    name: str = Field(min_length=2, max_length=150)
    strength: str | None = Field(default=None, max_length=100)
    dosage_form: str | None = Field(default=None, max_length=100)
    language: Literal["en", "ur"] = "en"

    @field_validator("name")
    @classmethod
    def clean_name(cls, value: str) -> str:
        value = " ".join(value.split())
        if len(value) < 2 or not any(c.isalpha() for c in value):
            raise ValueError("Enter a medicine name.")
        return value


class MedicineOverview(StrictSchema):
    status: Literal["available", "needs_selection", "unavailable"]
    reference_name: str | None = None
    medication_id: UUID | None = None
    explanation: AiAnswerRead | None = None
    message: str
    prescription_confirmed: Literal[False] = False
    reference_scope: Literal["product", "ingredient"] = "product"
    reference_note: str | None = None
    identity_sources: list[SourceReferenceRead] = Field(default_factory=list)
    name_relationship: Literal["brand", "generic", "synonym", "product"] | None = None


def _compact(value: str) -> str:
    return re.sub(r"\s+", "", normalize_search(value))


def _form(value: str) -> str:
    value = normalize_search(value).rstrip(".")
    return {
        "tab": "tablet",
        "tabs": "tablet",
        "tablets": "tablet",
        "cap": "capsule",
        "caps": "capsule",
        "capsules": "capsule",
    }.get(value, value)


def select_reference(
    request: MedicineOverviewRequest, candidates: list[MedicationCandidateRead]
) -> MedicationCandidateRead | None:
    matches = []
    for candidate in candidates:
        if not candidate.strength and not candidate.dosage_form:
            # Bare ingredient/brand concepts go through ingredient relationships below;
            # a brand string alone must not be parsed as its own active ingredient.
            continue
        names = [candidate.canonical_name, candidate.brand_name or "", candidate.generic_name or ""]
        if normalize_search(request.name) not in {normalize_search(n) for n in names if n}:
            continue  # No fuzzy guesses or OCR correction for automatic previews.
        if request.strength and _compact(request.strength) != _compact(candidate.strength or ""):
            continue
        if request.dosage_form and _form(request.dosage_form) not in _form(
            candidate.dosage_form or ""
        ):
            continue
        matches.append(candidate)
    # Duplicate providers may describe the same exact reference. Different products
    # use the general ingredient explanation instead of an arbitrary product selection.
    concepts = {normalize_search(m.canonical_name) for m in matches}
    return matches[0] if len(concepts) == 1 else None


class MedicineOverviewService:
    def __init__(self, db: Session, settings: Settings):
        self.db = db
        self.settings = settings

    def prepare(self, request: MedicineOverviewRequest) -> MedicineOverview:
        service = MedicationIntelligenceService(self.db, self.settings)
        failures: list[dict[str, object]] = []
        try:
            candidates = [
                service._rank(c, request.name, request.strength, request.dosage_form, None)
                for c in service.reference.search(request.name)
            ]
            candidate = (
                select_reference(request, candidates)
                if request.strength and request.dosage_form
                else None
            )
            brand = lookup_brand(request.name)
            # A fully specified exact installed product or a verified ingredient
            # mapping needs no remote search. A bare name never selects the sole
            # product from an incomplete local catalogue.
            if (
                candidate is None
                and brand is None
                and service._provider_enabled("rxnorm_provider", self.settings.rxnorm_enabled)
            ):
                candidates.extend(
                    service._run_search(
                        service.rxnorm,
                        request.name,
                        None,
                        request.strength,
                        request.dosage_form,
                        failures,
                    )
                )
                candidate = select_reference(request, candidates)
            scope: Literal["product", "ingredient"] = "product"
            identity_sources: list[SourceReferenceRead] = []
            note = None
            used_brand_reference = False
            relationship: Literal["brand", "generic", "synonym", "product"] | None = None
            if candidate is None and brand:
                reference, version = brand
                ingredient_candidates = [
                    service._rank(c, reference.ingredient, None, None, None)
                    for c in service.reference.search(reference.ingredient)
                ]
                candidate = next(
                    (
                        c
                        for c in ingredient_candidates
                        if c.canonical_name.casefold() == reference.ingredient.casefold()
                        and any(
                            i.type == "rxcui" and i.value == reference.rxcui for i in c.identifiers
                        )
                        and c.strength is None
                    ),
                    None,
                )
                if candidate is None and service._provider_enabled(
                    "rxnorm_provider", self.settings.rxnorm_enabled
                ):
                    exact_ingredient = service.rxnorm.ingredient(
                        reference.rxcui, reference.ingredient
                    )
                    if exact_ingredient:
                        candidate = service._rank(
                            exact_ingredient, reference.ingredient, None, None, None
                        )
                if candidate:
                    used_brand_reference = True
                    scope = "ingredient"
                    relationship = "brand"
                    identity_sources = [reference.citation(version)]
                    note = (
                        f"{reference.brand} is linked to {reference.ingredient} by the cited "
                        f"{reference.jurisdiction} reference. This explains the ingredient only; "
                        "the prescribed strength, release type and exact product are not confirmed."
                    )
            if candidate is None:
                general = MedicineNameResolver(service).resolve(request.name)
                if general:
                    candidate = general.candidate
                    scope = "ingredient"
                    relationship = general.relationship
                    identity_sources = general.sources
                    note = (
                        "General information; your prescribed product and instructions "
                        "are not confirmed."
                    )
            if candidate is None:
                return MedicineOverview(
                    status="unavailable",
                    message=f"No verified medicine reference was found for “{request.name}”. "
                    "Check the spelling against the prescription or medicine label, "
                    "then correct the name to get its explanation.",
                )
            medicine = service.reference_identity(candidate)
            if used_brand_reference and brand:
                cache_brand_reference(self.db, medicine, brand[0], brand[1])
            service.refresh_facts(medicine)
            medicine = service.identity(medicine.id) or medicine
            return MedicineOverview(
                status="available",
                reference_name=medicine.canonical_display_name,
                medication_id=medicine.id,
                message="General medicine information. Check the name against your prescription.",
                reference_scope=scope,
                reference_note=note,
                identity_sources=identity_sources,
                name_relationship=relationship,
            )
        finally:
            service.client.close()

    def overview(self, user_id: UUID, request: MedicineOverviewRequest) -> MedicineOverview:
        prepared = self.prepare(request)
        if prepared.status != "available" or prepared.medication_id is None:
            return prepared
        rag = MedicalRagService(self.db, self.settings)
        try:
            answer = rag.answer(
                user_id=user_id,
                request=AiQuestionRequest(
                    medication_id=prepared.medication_id,
                    language=request.language,
                    question=(
                        "What is this medicine used for? Explain to a patient with no "
                        "medical training in two or three short sentences, under 70 words. "
                        "Describe its main everyday purpose and how it helps, using only "
                        "simple words. Omit specialist class names, unexplained abbreviations "
                        "and long lists of diseases. Mention only one or two main uses; "
                        "explain necessary medical terms in everyday words. "
                        "Use only the supplied medicine names, not alternate brands "
                        "or synonyms. "
                        "Do not include doses, strengths, schedules, rare uses or "
                        "treatment instructions."
                    ),
                ),
            )
        finally:
            rag.client.close()
        if answer.grounding_status != "grounded" or not answer.source_references:
            return prepared.model_copy(
                update={
                    "status": "unavailable",
                    "message": "Explanation unavailable. Retry or check the official source.",
                }
            )
        return prepared.model_copy(update={"explanation": answer})
