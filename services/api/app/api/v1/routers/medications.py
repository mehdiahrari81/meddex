from uuid import UUID

from fastapi import APIRouter, HTTPException, Response
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.api.dependencies import CurrentIdentityDependency, DatabaseDependency
from app.core.security import ensure_utc
from app.core.time import utc_now
from app.models import (
    DoseEvent,
    MedicationPlan,
    MedicationPlanSource,
    MedicationSchedule,
    Prescription,
    PrescriptionItem,
    ReminderTime,
    UserMedication,
)
from app.schemas.medication import (
    DoseEventRead,
    DoseEventUpsert,
    MedicationPlanRead,
    MedicationPlanUpsert,
    SchedulePayload,
)

router = APIRouter(prefix="/medications", tags=["medications"])


def _verified_prescription_item(db: DatabaseDependency, user_id: UUID, client_item_id: str) -> bool:
    item = db.scalar(
        select(PrescriptionItem)
        .join(Prescription, PrescriptionItem.prescription_id == Prescription.id)
        .where(
            Prescription.user_id == user_id,
            Prescription.deleted_at.is_(None),
            Prescription.verification_state == "readyForMedicationLookup",
            Prescription.user_confirmed_at.is_not(None),
            PrescriptionItem.client_id == client_item_id,
            PrescriptionItem.state == "readyForLookup",
        )
    )
    if item is None:
        return False
    identity = next((field for field in item.fields if field.get("type") == "medicationName"), None)
    return bool(identity and identity.get("user_confirmed") and identity.get("current_value"))


def _schedule_payload(schedule: MedicationSchedule) -> SchedulePayload:
    return SchedulePayload(
        type=schedule.schedule_type,
        reminder_times=[
            value.minutes_after_midnight
            for value in sorted(schedule.reminder_times, key=lambda item: item.position)
        ],
        weekdays=schedule.weekdays,
        interval_hours=schedule.interval_hours,
        interval_anchor=schedule.interval_anchor,
        as_needed=schedule.as_needed,
    )


def _read(plan: MedicationPlan) -> MedicationPlanRead:
    schedule = plan.schedules[0]
    return MedicationPlanRead(
        id=plan.client_id,
        medication_id=plan.medication.client_id,
        prescription_item_id=plan.prescription_item_client_id,
        source_type=plan.medication.source_type,
        display_name=plan.medication.display_name,
        strength=plan.medication.strength,
        dosage_form=plan.medication.dosage_form,
        confirmed_dose_text=plan.confirmed_dose_text,
        confirmed_frequency=plan.confirmed_frequency,
        confirmed_duration=plan.confirmed_duration,
        raw_prescription_instruction=plan.source.raw_prescription_instruction,
        confirmed_instruction=plan.source.confirmed_instruction,
        start_date=plan.start_date,
        end_date=plan.end_date,
        instructions=plan.instructions,
        timezone=plan.timezone,
        schedule=_schedule_payload(schedule),
        medication_status=plan.medication.status,
        updated_at=plan.updated_at,
        revision=plan.revision,
        active=plan.active,
    )


def _owned_plan(db: DatabaseDependency, user_id: UUID, client_id: str) -> MedicationPlan:
    plan = db.scalar(
        select(MedicationPlan)
        .options(
            selectinload(MedicationPlan.medication),
            selectinload(MedicationPlan.source),
            selectinload(MedicationPlan.schedules).selectinload(MedicationSchedule.reminder_times),
        )
        .where(
            MedicationPlan.user_id == user_id,
            MedicationPlan.client_id == client_id,
            MedicationPlan.deleted_at.is_(None),
        )
    )
    if plan is None:
        raise HTTPException(status_code=404, detail="Medication plan not found")
    return plan


@router.put("/plans/{plan_id}", response_model=MedicationPlanRead)
def upsert_plan(
    plan_id: str,
    payload: MedicationPlanUpsert,
    identity: CurrentIdentityDependency,
    db: DatabaseDependency,
) -> MedicationPlanRead:
    if payload.id != plan_id:
        raise HTTPException(status_code=422, detail="Plan ID does not match path")
    if payload.source_type == "confirmedPrescription" and not _verified_prescription_item(
        db, identity.user.id, payload.prescription_item_id or ""
    ):
        raise HTTPException(
            status_code=409, detail="Unverified prescription data cannot create a plan"
        )
    existing = db.scalar(
        select(MedicationPlan)
        .options(
            selectinload(MedicationPlan.medication),
            selectinload(MedicationPlan.source),
            selectinload(MedicationPlan.schedules).selectinload(MedicationSchedule.reminder_times),
        )
        .where(MedicationPlan.user_id == identity.user.id, MedicationPlan.client_id == plan_id)
    )
    if existing is not None and ensure_utc(payload.updated_at) <= ensure_utc(existing.updated_at):
        return _read(existing)
    now = utc_now()
    if existing is None:
        medication = UserMedication(
            client_id=payload.medication_id,
            user_id=identity.user.id,
            prescription_item_client_id=payload.prescription_item_id,
            source_type=payload.source_type,
            display_name=payload.display_name,
            strength=payload.strength,
            dosage_form=payload.dosage_form,
            information_status="unavailable",
            status=payload.medication_status,
            created_at=now,
            updated_at=payload.updated_at,
        )
        db.add(medication)
        db.flush()
        existing = MedicationPlan(
            client_id=payload.id,
            user_id=identity.user.id,
            medication_id=medication.id,
            prescription_item_client_id=payload.prescription_item_id,
            confirmed_dose_text=payload.confirmed_dose_text,
            confirmed_frequency=payload.confirmed_frequency,
            confirmed_duration=payload.confirmed_duration,
            start_date=payload.start_date,
            end_date=payload.end_date,
            instructions=payload.instructions,
            timezone=payload.timezone,
            active=payload.active,
            created_at=now,
            updated_at=payload.updated_at,
        )
        db.add(existing)
        db.flush()
        existing.source = MedicationPlanSource(
            plan_id=existing.id,
            source_type=payload.source_type,
            raw_prescription_instruction=payload.raw_prescription_instruction,
            confirmed_instruction=payload.confirmed_instruction,
            confirmed_at=now,
        )
        existing.schedules = []
    else:
        # The confirmed source snapshot is intentionally immutable.
        if existing.source.confirmed_instruction != payload.confirmed_instruction:
            raise HTTPException(status_code=409, detail="Confirmed source instruction is immutable")
        existing.revision += 1
        existing.medication.display_name = payload.display_name
        existing.medication.strength = payload.strength
        existing.medication.dosage_form = payload.dosage_form
        existing.medication.status = payload.medication_status
        existing.schedules.clear()
    existing.prescription_item_client_id = payload.prescription_item_id
    existing.confirmed_dose_text = payload.confirmed_dose_text
    existing.confirmed_frequency = payload.confirmed_frequency
    existing.confirmed_duration = payload.confirmed_duration
    existing.start_date = payload.start_date
    existing.end_date = payload.end_date
    existing.instructions = payload.instructions
    existing.timezone = payload.timezone
    existing.active = payload.active
    existing.updated_at = payload.updated_at
    schedule = MedicationSchedule(
        plan_id=existing.id,
        schedule_type=payload.schedule.type,
        interval_hours=payload.schedule.interval_hours,
        interval_anchor=payload.schedule.interval_anchor,
        weekdays=payload.schedule.weekdays,
        as_needed=payload.schedule.as_needed,
        active=payload.active and not payload.schedule.as_needed,
        created_at=now,
        updated_at=payload.updated_at,
    )
    schedule.reminder_times = [
        ReminderTime(minutes_after_midnight=value, position=index, created_at=now)
        for index, value in enumerate(payload.schedule.reminder_times)
    ]
    existing.schedules.append(schedule)
    db.commit()
    return _read(_owned_plan(db, identity.user.id, plan_id))


@router.get("/plans", response_model=list[MedicationPlanRead])
def list_plans(
    identity: CurrentIdentityDependency, db: DatabaseDependency
) -> list[MedicationPlanRead]:
    plans = db.scalars(
        select(MedicationPlan)
        .options(
            selectinload(MedicationPlan.medication),
            selectinload(MedicationPlan.source),
            selectinload(MedicationPlan.schedules).selectinload(MedicationSchedule.reminder_times),
        )
        .where(MedicationPlan.user_id == identity.user.id, MedicationPlan.deleted_at.is_(None))
        .order_by(MedicationPlan.updated_at.desc())
    ).all()
    return [_read(plan) for plan in plans]


@router.delete("/plans/{plan_id}", status_code=204)
def delete_plan(
    plan_id: str,
    identity: CurrentIdentityDependency,
    db: DatabaseDependency,
) -> Response:
    plan = _owned_plan(db, identity.user.id, plan_id)
    plan.active = False
    plan.deleted_at = utc_now()
    plan.updated_at = plan.deleted_at
    plan.revision += 1
    db.commit()
    return Response(status_code=204)


@router.put("/dose-events/{event_id}", response_model=DoseEventRead)
def upsert_dose_event(
    event_id: str,
    payload: DoseEventUpsert,
    identity: CurrentIdentityDependency,
    db: DatabaseDependency,
) -> DoseEventRead:
    if event_id != payload.id:
        raise HTTPException(status_code=422, detail="Event ID does not match path")
    plan = _owned_plan(db, identity.user.id, payload.medication_plan_id)
    existing = db.scalar(
        select(DoseEvent).where(
            DoseEvent.user_id == identity.user.id, DoseEvent.client_id == payload.id
        )
    )
    if existing is not None:
        return DoseEventRead(
            **payload.model_dump(), accepted_as_latest=_is_latest(db, identity.user.id, existing)
        )
    event = DoseEvent(
        client_id=payload.id,
        user_id=identity.user.id,
        plan_id=plan.id,
        logical_dose_id=payload.logical_dose_id,
        scheduled_at=payload.scheduled_at,
        action=payload.action,
        recorded_at=payload.recorded_at,
        source=payload.source,
        note=payload.note,
        supersedes_event_client_id=payload.supersedes_event_id,
        revision=payload.revision,
    )
    db.add(event)
    db.commit()
    return DoseEventRead(
        **payload.model_dump(), accepted_as_latest=_is_latest(db, identity.user.id, event)
    )


def _is_latest(db: DatabaseDependency, user_id: UUID, event: DoseEvent) -> bool:
    latest = db.scalar(
        select(DoseEvent)
        .where(DoseEvent.user_id == user_id, DoseEvent.logical_dose_id == event.logical_dose_id)
        .order_by(
            DoseEvent.revision.desc(), DoseEvent.recorded_at.desc(), DoseEvent.client_id.desc()
        )
    )
    return latest is not None and latest.id == event.id
