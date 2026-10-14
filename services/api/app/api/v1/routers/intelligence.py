from uuid import UUID

import httpx
from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select

from app.api.dependencies import CurrentIdentityDependency, DatabaseDependency, SettingsDependency
from app.core.time import utc_now
from app.models import GovernanceReport, MedicationIdentity, MedicationResolution, SavedMedication
from app.schemas.intelligence import (
    AiAnswerRead,
    AiQuestionRequest,
    BarcodeResolveRequest,
    InformationReportCreate,
    MedicationCandidateRead,
    MedicationIdentityRead,
    ResolutionConfirm,
    ResolutionCreate,
    ResolutionRead,
)
from app.services.medical_rag import MedicalRagService
from app.services.medication_intelligence import MedicationIntelligenceService

router = APIRouter(prefix="/medication-intelligence", tags=["medication-intelligence"])


def _resolution_read(value: MedicationResolution) -> ResolutionRead:
    return ResolutionRead(
        id=value.id,
        state=value.state,
        normalized_search_string=value.normalized_search_string,
        candidates=[MedicationCandidateRead.model_validate(item) for item in value.candidates],
        provider_failures=[
            {str(key): str(item) for key, item in failure.items()}
            for failure in value.provider_failures
        ],
        medication_id=value.medication_id,
    )


def _identity_read(
    value: MedicationIdentity, cache_state: str, interaction_state: str
) -> MedicationIdentityRead:
    from app.schemas.intelligence import (
        CandidateIdentifier,
        IngredientRead,
        MedicalFactRead,
        SourceReferenceRead,
    )

    return MedicationIdentityRead(
        id=value.id,
        canonical_display_name=value.canonical_display_name,
        generic_name=value.generic_name,
        brand_names=value.brand_names,
        ingredients=[
            IngredientRead(
                name=item.name,
                numerator_value=item.numerator_value,
                numerator_unit=item.numerator_unit,
                denominator_value=item.denominator_value,
                denominator_unit=item.denominator_unit,
            )
            for item in sorted(value.ingredients, key=lambda item: item.position)
        ],
        dosage_form=value.dosage_form,
        country=value.country,
        identifiers=[
            CandidateIdentifier(
                type=item.identifier_type, value=item.value, jurisdiction=item.jurisdiction
            )
            for item in value.identifiers
        ],
        verification_state=value.verification_state,
        facts=[
            MedicalFactRead(
                id=item.id,
                type=item.fact_type,
                content=item.content,
                review_status=item.review_status,
                source=SourceReferenceRead(
                    id=str(item.id),
                    provider=item.provider,
                    title=item.source_title,
                    section=item.source_section,
                    jurisdiction=item.jurisdiction,
                    language=item.language,
                    content_version=item.content_version,
                    retrieved_at=item.retrieved_at,
                    source_updated_at=item.source_updated_at,
                    url=item.citation_reference,
                ),
            )
            for item in sorted(
                value.facts, key=lambda item: (item.fact_type, item.retrieved_at), reverse=True
            )
        ],
        cache_state=cache_state,
        interaction_provider_state=interaction_state,
    )


@router.post("/resolutions", response_model=ResolutionRead, status_code=status.HTTP_201_CREATED)
def create_resolution(
    payload: ResolutionCreate,
    identity: CurrentIdentityDependency,
    db: DatabaseDependency,
    settings: SettingsDependency,
) -> ResolutionRead:
    service = MedicationIntelligenceService(db, settings)
    try:
        value = service.create_resolution(
            user_id=identity.user.id,
            raw_value=payload.raw_confirmed_value,
            input_origin=payload.input_origin,
            strength=payload.strength,
            dosage_form=payload.dosage_form,
            country=payload.country,
            prescription_item_id=payload.prescription_item_id,
        )
    except ValueError as error:
        raise HTTPException(status_code=409, detail=str(error)) from error
    return _resolution_read(value)


@router.get("/resolutions/{resolution_id}", response_model=ResolutionRead)
def read_resolution(
    resolution_id: UUID,
    identity: CurrentIdentityDependency,
    db: DatabaseDependency,
    settings: SettingsDependency,
) -> ResolutionRead:
    value = MedicationIntelligenceService(db, settings).resolution(identity.user.id, resolution_id)
    if value is None:
        raise HTTPException(status_code=404, detail="Resolution not found")
    return _resolution_read(value)


@router.post("/resolutions/{resolution_id}/confirm", response_model=MedicationIdentityRead)
def confirm_resolution(
    resolution_id: UUID,
    payload: ResolutionConfirm,
    identity: CurrentIdentityDependency,
    db: DatabaseDependency,
    settings: SettingsDependency,
) -> MedicationIdentityRead:
    service = MedicationIntelligenceService(db, settings)
    try:
        _, medication = service.confirm(identity.user.id, resolution_id, payload.candidate_id)
    except LookupError as error:
        raise HTTPException(status_code=404, detail="Resolution not found") from error
    except ValueError as error:
        raise HTTPException(
            status_code=409, detail="Candidate is not part of this resolution"
        ) from error
    return _identity_read(medication, "current", service.interactions.state)


@router.get("/medications/{medication_id}", response_model=MedicationIdentityRead)
def medication_detail(
    medication_id: UUID,
    identity: CurrentIdentityDependency,
    db: DatabaseDependency,
    settings: SettingsDependency,
) -> MedicationIdentityRead:
    service = MedicationIntelligenceService(db, settings)
    medication = service.identity(medication_id)
    if medication is None:
        raise HTTPException(status_code=404, detail="Medication identity not found")
    cache_state = service.refresh_facts(medication)
    medication = service.identity(medication_id) or medication
    return _identity_read(medication, cache_state, service.interactions.state)


@router.post("/barcodes/resolve", response_model=MedicationCandidateRead | None)
def resolve_barcode(
    payload: BarcodeResolveRequest,
    identity: CurrentIdentityDependency,
    db: DatabaseDependency,
    settings: SettingsDependency,
) -> MedicationCandidateRead | None:
    service = MedicationIntelligenceService(db, settings)
    candidate = service.resolve_barcode(payload.value)
    if candidate is None:
        return None
    return service._rank(candidate, payload.value, None, None, None)


@router.get("/saved", response_model=list[MedicationIdentityRead])
def saved_medications(
    identity: CurrentIdentityDependency,
    db: DatabaseDependency,
    settings: SettingsDependency,
) -> list[MedicationIdentityRead]:
    service = MedicationIntelligenceService(db, settings)
    saved = db.scalars(
        select(SavedMedication)
        .where(SavedMedication.user_id == identity.user.id)
        .order_by(SavedMedication.saved_at.desc())
        .limit(100)
    ).all()
    values = [service.identity(item.medication_id) for item in saved]
    return [
        _identity_read(value, "current", service.interactions.state)
        for value in values
        if value is not None
    ]


@router.put("/saved/{medication_id}", status_code=204)
def save_medication(
    medication_id: UUID,
    identity: CurrentIdentityDependency,
    db: DatabaseDependency,
    settings: SettingsDependency,
) -> None:
    service = MedicationIntelligenceService(db, settings)
    if service.identity(medication_id) is None:
        raise HTTPException(status_code=404, detail="Medication identity not found")
    existing = db.scalar(
        select(SavedMedication).where(
            SavedMedication.user_id == identity.user.id,
            SavedMedication.medication_id == medication_id,
        )
    )
    if existing is None:
        db.add(SavedMedication(user_id=identity.user.id, medication_id=medication_id))
        db.commit()


@router.delete("/saved/{medication_id}", status_code=204)
def unsave_medication(
    medication_id: UUID,
    identity: CurrentIdentityDependency,
    db: DatabaseDependency,
) -> None:
    value = db.scalar(
        select(SavedMedication).where(
            SavedMedication.user_id == identity.user.id,
            SavedMedication.medication_id == medication_id,
        )
    )
    if value is not None:
        db.delete(value)
        db.commit()


@router.post("/ai/answer", response_model=AiAnswerRead)
def answer_question(
    payload: AiQuestionRequest,
    identity: CurrentIdentityDependency,
    db: DatabaseDependency,
    settings: SettingsDependency,
) -> AiAnswerRead:
    with httpx.Client(timeout=settings.ai_timeout_seconds) as client:
        return MedicalRagService(db, settings, client=client).answer(
            user_id=identity.user.id, request=payload
        )


@router.post("/reports", status_code=status.HTTP_201_CREATED)
def report_information(
    payload: InformationReportCreate,
    identity: CurrentIdentityDependency,
    db: DatabaseDependency,
) -> dict[str, str]:
    report = GovernanceReport(
        user_id=identity.user.id,
        report_type=payload.report_type,
        target_type=payload.target_type,
        target_id=payload.target_id,
        reason=payload.reason,
        redacted_context={"has_note": bool(payload.note)},
        status="open",
        created_at=utc_now(),
    )
    db.add(report)
    db.commit()
    return {"id": str(report.id), "status": report.status}
