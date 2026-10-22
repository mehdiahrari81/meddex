from datetime import date, datetime
from typing import Literal

from pydantic import Field, model_validator

from app.schemas.common import StrictSchema

MedicationSource = Literal["confirmedPrescription", "manualEntry", "confirmedLookup"]
MedicationStatus = Literal["active", "completed", "pausedByUser", "archived", "unresolved"]
ScheduleType = Literal[
    "onceDaily",
    "twiceDaily",
    "threeTimesDaily",
    "fourTimesDaily",
    "everyNHours",
    "selectedWeekdays",
    "specificDays",
    "custom",
    "asNeeded",
]
DoseAction = Literal["taken", "skipped", "notRecorded", "late"]
DoseSource = Literal["notificationAction", "app", "manualEntry", "voiceConfirmed"]


class SchedulePayload(StrictSchema):
    type: ScheduleType
    reminder_times: list[int] = Field(default_factory=list, max_length=24)
    weekdays: list[int] = Field(default_factory=list, max_length=7)
    interval_hours: int | None = Field(default=None, ge=1, le=168)
    interval_anchor: datetime | None = None
    as_needed: bool = False

    @model_validator(mode="after")
    def valid_schedule(self) -> "SchedulePayload":
        if any(value < 0 or value >= 1440 for value in self.reminder_times):
            raise ValueError("reminder times must be minutes within a day")
        if self.as_needed and self.reminder_times:
            raise ValueError("as-needed medicines cannot have fixed reminders by default")
        if self.type == "everyNHours" and (
            self.interval_hours is None or self.interval_anchor is None
        ):
            raise ValueError("every-N-hours schedules require interval and anchor")
        return self


class MedicationPlanUpsert(StrictSchema):
    id: str = Field(min_length=1, max_length=100)
    medication_id: str = Field(min_length=1, max_length=100)
    prescription_item_id: str | None = Field(default=None, max_length=100)
    source_type: MedicationSource
    display_name: str = Field(min_length=1, max_length=300)
    strength: str | None = Field(default=None, max_length=100)
    dosage_form: str | None = Field(default=None, max_length=100)
    confirmed_dose_text: str = Field(max_length=500)
    confirmed_frequency: str = Field(max_length=500)
    confirmed_duration: str | None = Field(default=None, max_length=500)
    raw_prescription_instruction: str | None = Field(default=None, max_length=4000)
    confirmed_instruction: str = Field(min_length=1, max_length=4000)
    start_date: date
    end_date: date | None = None
    instructions: str | None = Field(default=None, max_length=4000)
    timezone: str = Field(min_length=1, max_length=100)
    schedule: SchedulePayload
    medication_status: MedicationStatus = "active"
    active: bool = True
    updated_at: datetime

    @model_validator(mode="after")
    def source_has_confirmation(self) -> "MedicationPlanUpsert":
        if self.active and (
            not self.confirmed_dose_text.strip() or not self.confirmed_frequency.strip()
        ):
            raise ValueError("Active reminders require confirmed dose and frequency")
        if self.end_date is not None and self.end_date < self.start_date:
            raise ValueError("end date cannot precede start date")
        return self


class MedicationPlanRead(MedicationPlanUpsert):
    revision: int
    active: bool


class DoseEventUpsert(StrictSchema):
    id: str = Field(min_length=1, max_length=100)
    medication_plan_id: str = Field(min_length=1, max_length=100)
    logical_dose_id: str = Field(min_length=1, max_length=250)
    scheduled_at: datetime | None = None
    action: DoseAction
    recorded_at: datetime
    source: DoseSource
    note: str | None = Field(default=None, max_length=1000)
    supersedes_event_id: str | None = Field(default=None, max_length=100)
    revision: int = Field(ge=1)

    @model_validator(mode="after")
    def scheduled_actions_have_time(self) -> "DoseEventUpsert":
        if self.source != "manualEntry" and self.scheduled_at is None:
            raise ValueError("scheduled dose action requires scheduled_at")
        return self


class DoseEventRead(DoseEventUpsert):
    accepted_as_latest: bool
