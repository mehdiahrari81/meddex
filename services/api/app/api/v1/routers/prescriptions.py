from uuid import UUID

from fastapi import APIRouter, HTTPException, Response, status
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.api.dependencies import CurrentIdentityDependency, DatabaseDependency
from app.core.security import ensure_utc
from app.core.time import utc_now
from app.models import BarcodeScan, Prescription, PrescriptionItem, PrescriptionReport
from app.schemas.prescription import (
    BarcodeCreate,
    BarcodeRead,
    PrescriptionCreate,
    PrescriptionItemCreate,
    PrescriptionItemPatch,
    PrescriptionItemRead,
    PrescriptionPatch,
    PrescriptionRead,
    PrescriptionReportCreate,
    PrescriptionReportRead,
    PrescriptionSummary,
)

router = APIRouter(prefix="/prescriptions", tags=["prescriptions"])


def _owned(db: DatabaseDependency, user_id: UUID, prescription_id: UUID) -> Prescription:
    value = db.scalar(
        select(Prescription)
        .options(selectinload(Prescription.items))
        .where(
            Prescription.id == prescription_id,
            Prescription.user_id == user_id,
            Prescription.deleted_at.is_(None),
        )
    )
    if value is None:
        raise HTTPException(status_code=404, detail="Prescription not found")
    return value


def _read(value: Prescription) -> PrescriptionRead:
    return PrescriptionRead(
        id=value.id,
        client_id=value.client_id,
        source_type=value.source_type,
        capture_date=value.capture_date,
        parser_version=value.parser_version,
        ocr_provider=value.ocr_provider,
        ocr_provider_version=value.ocr_provider_version,
        page_count=value.page_count,
        verification_state=value.verification_state,
        user_confirmed_at=value.user_confirmed_at,
        revision=value.revision,
        created_at=value.created_at,
        updated_at=value.updated_at,
        items=[
            PrescriptionItemRead(
                id=item.client_id,
                state=item.state,
                page_number=item.page_number,
                position=item.position,
                fields=item.fields,
                created_at=item.created_at,
                updated_at=item.updated_at,
            )
            for item in value.items
        ],
    )


def _replace_items(value: Prescription, payload: list[PrescriptionItemCreate]) -> None:
    by_client_id = {item.client_id: item for item in value.items}
    retained: list[PrescriptionItem] = []
    now = utc_now()
    for incoming in payload:
        item = by_client_id.get(incoming.id)
        if item is None:
            item = PrescriptionItem(
                client_id=incoming.id,
                prescription_id=value.id,
                created_at=now,
            )
        item.state = incoming.state
        item.page_number = incoming.page_number
        item.position = incoming.position
        item.fields = [field.model_dump(mode="json") for field in incoming.fields]
        item.updated_at = now
        retained.append(item)
    value.items = retained


@router.post("", response_model=PrescriptionRead, status_code=status.HTTP_201_CREATED)
def create_prescription(
    payload: PrescriptionCreate,
    identity: CurrentIdentityDependency,
    db: DatabaseDependency,
) -> PrescriptionRead:
    existing = db.scalar(
        select(Prescription)
        .options(selectinload(Prescription.items))
        .where(Prescription.user_id == identity.user.id, Prescription.client_id == payload.id)
    )
    if existing is not None:
        if ensure_utc(payload.updated_at) <= ensure_utc(existing.updated_at):
            return _read(existing)
        if (
            existing.verification_state == "readyForMedicationLookup"
            and payload.verification_state != "readyForMedicationLookup"
        ):
            raise HTTPException(
                status_code=409,
                detail="Confirmed prescription cannot be downgraded",
            )
        current_confirmed = {
            item.client_id: item for item in existing.items if item.state == "readyForLookup"
        }
        for incoming in payload.items:
            if incoming.id in current_confirmed and incoming.state != "readyForLookup":
                raise HTTPException(
                    status_code=409,
                    detail="Confirmed item cannot be downgraded",
                )
        existing.source_type = payload.source_type
        existing.capture_date = payload.capture_date
        existing.parser_version = payload.parser_version
        existing.ocr_provider = payload.ocr_provider
        existing.ocr_provider_version = payload.ocr_provider_version
        existing.page_count = payload.page_count
        existing.verification_state = payload.verification_state
        existing.user_confirmed_at = payload.user_confirmed_at
        _replace_items(
            existing,
            [PrescriptionItemCreate.model_validate(item) for item in payload.items],
        )
        existing.updated_at = payload.updated_at
        existing.revision += 1
        db.commit()
        return _read(_owned(db, identity.user.id, existing.id))
    now = utc_now()
    value = Prescription(
        id=UUID(payload.id),
        client_id=payload.id,
        user_id=identity.user.id,
        source_type=payload.source_type,
        capture_date=payload.capture_date,
        parser_version=payload.parser_version,
        ocr_provider=payload.ocr_provider,
        ocr_provider_version=payload.ocr_provider_version,
        page_count=payload.page_count,
        verification_state=payload.verification_state,
        user_confirmed_at=payload.user_confirmed_at,
        created_at=now,
        updated_at=payload.updated_at,
    )
    db.add(value)
    db.flush()
    _replace_items(value, [PrescriptionItemCreate.model_validate(item) for item in payload.items])
    db.commit()
    db.refresh(value)
    return _read(_owned(db, identity.user.id, value.id))


@router.get("", response_model=list[PrescriptionSummary])
def list_prescriptions(
    identity: CurrentIdentityDependency, db: DatabaseDependency
) -> list[PrescriptionSummary]:
    values = db.scalars(
        select(Prescription)
        .options(selectinload(Prescription.items))
        .where(Prescription.user_id == identity.user.id, Prescription.deleted_at.is_(None))
        .order_by(Prescription.updated_at.desc())
    ).all()
    return [
        PrescriptionSummary(
            id=value.id,
            client_id=value.client_id,
            capture_date=value.capture_date,
            verification_state=value.verification_state,
            item_count=len(value.items),
            unresolved_count=sum(
                item.state in {"detected", "needsReview", "edited", "unresolved"}
                for item in value.items
            ),
            revision=value.revision,
            updated_at=value.updated_at,
        )
        for value in values
    ]


@router.get("/{prescription_id}", response_model=PrescriptionRead)
def read_prescription(
    prescription_id: UUID,
    identity: CurrentIdentityDependency,
    db: DatabaseDependency,
) -> PrescriptionRead:
    return _read(_owned(db, identity.user.id, prescription_id))


@router.patch("/{prescription_id}", response_model=PrescriptionRead)
def patch_prescription(
    prescription_id: UUID,
    payload: PrescriptionPatch,
    identity: CurrentIdentityDependency,
    db: DatabaseDependency,
) -> PrescriptionRead:
    value = _owned(db, identity.user.id, prescription_id)
    if payload.revision != value.revision:
        raise HTTPException(status_code=409, detail="Prescription revision conflict")
    if ensure_utc(payload.updated_at) < ensure_utc(value.updated_at):
        raise HTTPException(status_code=409, detail="Older data cannot overwrite this prescription")
    if payload.verification_state is not None:
        value.verification_state = payload.verification_state
    value.user_confirmed_at = payload.user_confirmed_at
    if payload.items is not None:
        current_confirmed = {
            item.client_id: item for item in value.items if item.state == "readyForLookup"
        }
        for incoming in payload.items:
            if incoming.id in current_confirmed and incoming.state != "readyForLookup":
                raise HTTPException(status_code=409, detail="Confirmed item cannot be downgraded")
        _replace_items(
            value, [PrescriptionItemCreate.model_validate(item) for item in payload.items]
        )
    value.updated_at = payload.updated_at
    value.revision += 1
    db.commit()
    return _read(_owned(db, identity.user.id, value.id))


@router.delete("/{prescription_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_prescription(
    prescription_id: UUID,
    identity: CurrentIdentityDependency,
    db: DatabaseDependency,
) -> Response:
    # Offline drafts may never have reached the server, and a successful delete
    # can be retried after its response is lost. Both cases are already complete.
    value = db.scalar(
        select(Prescription).where(
            Prescription.id == prescription_id,
            Prescription.user_id == identity.user.id,
            Prescription.deleted_at.is_(None),
        )
    )
    if value is not None:
        value.deleted_at = utc_now()
        value.updated_at = value.deleted_at
        value.revision += 1
        db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/{prescription_id}/items", response_model=PrescriptionItemRead, status_code=201)
def add_item(
    prescription_id: UUID,
    payload: PrescriptionItemCreate,
    identity: CurrentIdentityDependency,
    db: DatabaseDependency,
) -> PrescriptionItemRead:
    value = _owned(db, identity.user.id, prescription_id)
    existing = next((item for item in value.items if item.client_id == payload.id), None)
    if existing is not None:
        return PrescriptionItemRead(
            id=existing.client_id,
            state=existing.state,
            page_number=existing.page_number,
            position=existing.position,
            fields=existing.fields,
            created_at=existing.created_at,
            updated_at=existing.updated_at,
        )
    now = utc_now()
    item = PrescriptionItem(
        client_id=payload.id,
        prescription_id=value.id,
        state=payload.state,
        page_number=payload.page_number,
        position=payload.position,
        fields=[field.model_dump(mode="json") for field in payload.fields],
        created_at=now,
        updated_at=now,
    )
    db.add(item)
    value.updated_at = now
    value.revision += 1
    db.commit()
    db.refresh(item)
    return PrescriptionItemRead(
        id=item.client_id,
        state=item.state,
        page_number=item.page_number,
        position=item.position,
        fields=item.fields,
        created_at=item.created_at,
        updated_at=item.updated_at,
    )


@router.patch("/{prescription_id}/items/{item_id}", response_model=PrescriptionItemRead)
def patch_item(
    prescription_id: UUID,
    item_id: str,
    payload: PrescriptionItemPatch,
    identity: CurrentIdentityDependency,
    db: DatabaseDependency,
) -> PrescriptionItemRead:
    value = _owned(db, identity.user.id, prescription_id)
    item = next((candidate for candidate in value.items if candidate.client_id == item_id), None)
    if item is None:
        raise HTTPException(status_code=404, detail="Prescription item not found")
    if ensure_utc(payload.updated_at) < ensure_utc(item.updated_at):
        raise HTTPException(status_code=409, detail="Older data cannot overwrite this item")
    if item.state == "readyForLookup" and payload.state not in {None, "readyForLookup"}:
        raise HTTPException(status_code=409, detail="Confirmed item cannot be downgraded")
    if payload.state is not None:
        item.state = payload.state
    if payload.page_number is not None:
        item.page_number = payload.page_number
    if payload.position is not None:
        item.position = payload.position
    if payload.fields is not None:
        item.fields = [field.model_dump(mode="json") for field in payload.fields]
    item.updated_at = payload.updated_at
    value.updated_at = payload.updated_at
    value.revision += 1
    db.commit()
    db.refresh(item)
    return PrescriptionItemRead(
        id=item.client_id,
        state=item.state,
        page_number=item.page_number,
        position=item.position,
        fields=item.fields,
        created_at=item.created_at,
        updated_at=item.updated_at,
    )


@router.delete("/{prescription_id}/items/{item_id}", status_code=204)
def delete_item(
    prescription_id: UUID,
    item_id: str,
    identity: CurrentIdentityDependency,
    db: DatabaseDependency,
) -> Response:
    value = _owned(db, identity.user.id, prescription_id)
    item = next((candidate for candidate in value.items if candidate.client_id == item_id), None)
    if item is None:
        raise HTTPException(status_code=404, detail="Prescription item not found")
    db.delete(item)
    value.updated_at = utc_now()
    value.revision += 1
    db.commit()
    return Response(status_code=204)


@router.post("/{prescription_id}/confirm", response_model=PrescriptionRead)
def confirm_prescription(
    prescription_id: UUID,
    identity: CurrentIdentityDependency,
    db: DatabaseDependency,
) -> PrescriptionRead:
    value = _owned(db, identity.user.id, prescription_id)
    retained = [item for item in value.items if item.state != "rejected"]
    if not retained or any(item.state != "readyForLookup" for item in retained):
        raise HTTPException(
            status_code=409,
            detail="All retained medicine identities require confirmation",
        )
    value.verification_state = "readyForMedicationLookup"
    value.user_confirmed_at = utc_now()
    value.updated_at = value.user_confirmed_at
    value.revision += 1
    db.commit()
    return _read(_owned(db, identity.user.id, value.id))


@router.post("/{prescription_id}/reports", response_model=PrescriptionReportRead, status_code=201)
def report_prescription(
    prescription_id: UUID,
    payload: PrescriptionReportCreate,
    identity: CurrentIdentityDependency,
    db: DatabaseDependency,
) -> PrescriptionReportRead:
    value = _owned(db, identity.user.id, prescription_id)
    report = PrescriptionReport(
        prescription_id=value.id,
        user_id=identity.user.id,
        reason=payload.reason,
        note=payload.note,
    )
    db.add(report)
    db.commit()
    db.refresh(report)
    return PrescriptionReportRead.model_validate(report)


@router.post("/barcode-scans", response_model=BarcodeRead, status_code=201)
def record_barcode(
    payload: BarcodeCreate,
    identity: CurrentIdentityDependency,
    db: DatabaseDependency,
) -> BarcodeRead:
    existing = db.scalar(
        select(BarcodeScan).where(
            BarcodeScan.user_id == identity.user.id, BarcodeScan.client_id == payload.id
        )
    )
    if existing is None:
        existing = BarcodeScan(
            id=UUID(payload.id),
            client_id=payload.id,
            user_id=identity.user.id,
            format=payload.format,
            raw_value=payload.raw_value,
            source=payload.source,
            scanned_at=payload.scanned_at,
            user_confirmed=payload.user_confirmed,
        )
        db.add(existing)
        db.commit()
        db.refresh(existing)
    return BarcodeRead(
        id=existing.client_id,
        server_id=existing.id,
        format=existing.format,
        raw_value=existing.raw_value,
        source=existing.source,
        scanned_at=existing.scanned_at,
        user_confirmed=existing.user_confirmed,
    )
