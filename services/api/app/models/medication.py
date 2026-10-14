from datetime import date, datetime
from uuid import UUID, uuid4

from sqlalchemy import (
    JSON,
    Boolean,
    Date,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.time import utc_now
from app.db.base import Base


class UserMedication(Base):
    __tablename__ = "user_medications"
    __table_args__ = (UniqueConstraint("user_id", "client_id", name="uq_user_medication_client"),)

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    client_id: Mapped[str] = mapped_column(String(100))
    user_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    prescription_item_client_id: Mapped[str | None] = mapped_column(String(100))
    medication_information_id: Mapped[str | None] = mapped_column(String(100))
    source_type: Mapped[str] = mapped_column(String(40))
    display_name: Mapped[str] = mapped_column(String(300))
    generic_name: Mapped[str | None] = mapped_column(String(300))
    brand_name: Mapped[str | None] = mapped_column(String(300))
    strength: Mapped[str | None] = mapped_column(String(100))
    dosage_form: Mapped[str | None] = mapped_column(String(100))
    information_status: Mapped[str] = mapped_column(String(30), default="unavailable")
    status: Mapped[str] = mapped_column(String(30), default="active")
    revision: Mapped[int] = mapped_column(Integer, default=1)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)

    plans: Mapped[list["MedicationPlan"]] = relationship(
        back_populates="medication", cascade="all, delete-orphan"
    )


class MedicationPlan(Base):
    __tablename__ = "medication_plans"
    __table_args__ = (UniqueConstraint("user_id", "client_id", name="uq_medication_plan_client"),)

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    client_id: Mapped[str] = mapped_column(String(100))
    user_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    medication_id: Mapped[UUID] = mapped_column(
        ForeignKey("user_medications.id", ondelete="CASCADE"), index=True
    )
    prescription_item_client_id: Mapped[str | None] = mapped_column(String(100))
    confirmed_dose_text: Mapped[str] = mapped_column(String(500))
    confirmed_frequency: Mapped[str] = mapped_column(String(500))
    confirmed_duration: Mapped[str | None] = mapped_column(String(500))
    start_date: Mapped[date] = mapped_column(Date)
    end_date: Mapped[date | None] = mapped_column(Date)
    instructions: Mapped[str | None] = mapped_column(Text)
    timezone: Mapped[str] = mapped_column(String(100))
    active: Mapped[bool] = mapped_column(Boolean, default=True)
    revision: Mapped[int] = mapped_column(Integer, default=1)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)

    medication: Mapped[UserMedication] = relationship(back_populates="plans")
    source: Mapped["MedicationPlanSource"] = relationship(
        back_populates="plan", cascade="all, delete-orphan", single_parent=True
    )
    schedules: Mapped[list["MedicationSchedule"]] = relationship(
        back_populates="plan", cascade="all, delete-orphan"
    )


class MedicationPlanSource(Base):
    __tablename__ = "medication_plan_sources"

    plan_id: Mapped[UUID] = mapped_column(
        ForeignKey("medication_plans.id", ondelete="CASCADE"), primary_key=True
    )
    source_type: Mapped[str] = mapped_column(String(40))
    raw_prescription_instruction: Mapped[str | None] = mapped_column(Text)
    confirmed_instruction: Mapped[str] = mapped_column(Text)
    confirmed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)

    plan: Mapped[MedicationPlan] = relationship(back_populates="source")


class MedicationSchedule(Base):
    __tablename__ = "medication_schedules"

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    plan_id: Mapped[UUID] = mapped_column(
        ForeignKey("medication_plans.id", ondelete="CASCADE"), index=True
    )
    schedule_type: Mapped[str] = mapped_column(String(40))
    interval_hours: Mapped[int | None] = mapped_column(Integer)
    interval_anchor: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    weekdays: Mapped[list[int]] = mapped_column(JSON, default=list)
    as_needed: Mapped[bool] = mapped_column(Boolean, default=False)
    active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)

    plan: Mapped[MedicationPlan] = relationship(back_populates="schedules")
    reminder_times: Mapped[list["ReminderTime"]] = relationship(
        back_populates="schedule", cascade="all, delete-orphan"
    )


class ReminderTime(Base):
    __tablename__ = "reminder_times"

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    schedule_id: Mapped[UUID] = mapped_column(
        ForeignKey("medication_schedules.id", ondelete="CASCADE"), index=True
    )
    minutes_after_midnight: Mapped[int] = mapped_column(Integer)
    weekday: Mapped[int | None] = mapped_column(Integer)
    position: Mapped[int] = mapped_column(Integer)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)

    schedule: Mapped[MedicationSchedule] = relationship(back_populates="reminder_times")


class DoseEvent(Base):
    __tablename__ = "dose_events"
    __table_args__ = (
        UniqueConstraint("user_id", "client_id", name="uq_dose_event_client"),
        UniqueConstraint("user_id", "logical_dose_id", "revision", name="uq_dose_event_revision"),
    )

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    client_id: Mapped[str] = mapped_column(String(100))
    user_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    plan_id: Mapped[UUID] = mapped_column(
        ForeignKey("medication_plans.id", ondelete="CASCADE"), index=True
    )
    logical_dose_id: Mapped[str] = mapped_column(String(250), index=True)
    scheduled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    action: Mapped[str] = mapped_column(String(30))
    recorded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    source: Mapped[str] = mapped_column(String(40))
    note: Mapped[str | None] = mapped_column(Text)
    supersedes_event_client_id: Mapped[str | None] = mapped_column(String(100))
    revision: Mapped[int] = mapped_column(Integer)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class MedicationNote(Base):
    __tablename__ = "medication_notes"
    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    medication_id: Mapped[UUID] = mapped_column(
        ForeignKey("user_medications.id", ondelete="CASCADE"), index=True
    )
    note: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class RefillReminder(Base):
    __tablename__ = "refill_reminders"
    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    plan_id: Mapped[UUID] = mapped_column(
        ForeignKey("medication_plans.id", ondelete="CASCADE"), index=True
    )
    reminder_date: Mapped[date | None] = mapped_column(Date)
    starting_quantity: Mapped[float | None] = mapped_column(Float)
    quantity_per_taken_dose: Mapped[float | None] = mapped_column(Float)
    alert_at_remaining: Mapped[float | None] = mapped_column(Float)
    active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)


class MedicationPlanHistory(Base):
    __tablename__ = "medication_plan_history"
    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    plan_id: Mapped[UUID] = mapped_column(
        ForeignKey("medication_plans.id", ondelete="CASCADE"), index=True
    )
    action: Mapped[str] = mapped_column(String(60))
    safe_details: Mapped[dict[str, object]] = mapped_column(JSON, default=dict)
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)


class MedicationExportMetadata(Base):
    __tablename__ = "medication_export_metadata"
    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    format: Mapped[str] = mapped_column(String(30))
    included_fields: Mapped[list[str]] = mapped_column(JSON, default=list)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    shared_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class MedicationPrivacyPreference(Base):
    __tablename__ = "medication_privacy_preferences"
    user_id: Mapped[UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    notification_privacy: Mapped[str] = mapped_column(String(30), default="privateReminder")
    retain_prescription_images: Mapped[bool] = mapped_column(Boolean, default=False)
    sync_medication_history: Mapped[bool] = mapped_column(Boolean, default=False)
    hide_medicine_details: Mapped[bool] = mapped_column(Boolean, default=False)
    obscure_app_preview: Mapped[bool] = mapped_column(Boolean, default=True)
    daily_summary_enabled: Mapped[bool] = mapped_column(Boolean, default=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
