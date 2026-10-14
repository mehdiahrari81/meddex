"""module 5 medication assistant

Revision ID: 0004_module_5
Revises: 0003_module_3
Create Date: 2026-08-13 15:00:00
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0004_module_5"
down_revision: str | None = "0003_module_3"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "user_medications",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("client_id", sa.String(100), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("prescription_item_client_id", sa.String(100), nullable=True),
        sa.Column("medication_information_id", sa.String(100), nullable=True),
        sa.Column("source_type", sa.String(40), nullable=False),
        sa.Column("display_name", sa.String(300), nullable=False),
        sa.Column("generic_name", sa.String(300), nullable=True),
        sa.Column("brand_name", sa.String(300), nullable=True),
        sa.Column("strength", sa.String(100), nullable=True),
        sa.Column("dosage_form", sa.String(100), nullable=True),
        sa.Column("information_status", sa.String(30), nullable=False),
        sa.Column("status", sa.String(30), nullable=False),
        sa.Column("revision", sa.Integer(), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "client_id", name="uq_user_medication_client"),
    )
    op.create_index("ix_user_medications_user_id", "user_medications", ["user_id"])
    op.create_table(
        "medication_plans",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("client_id", sa.String(100), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("medication_id", sa.Uuid(), nullable=False),
        sa.Column("prescription_item_client_id", sa.String(100), nullable=True),
        sa.Column("confirmed_dose_text", sa.String(500), nullable=False),
        sa.Column("confirmed_frequency", sa.String(500), nullable=False),
        sa.Column("confirmed_duration", sa.String(500), nullable=True),
        sa.Column("start_date", sa.Date(), nullable=False),
        sa.Column("end_date", sa.Date(), nullable=True),
        sa.Column("instructions", sa.Text(), nullable=True),
        sa.Column("timezone", sa.String(100), nullable=False),
        sa.Column("active", sa.Boolean(), nullable=False),
        sa.Column("revision", sa.Integer(), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["medication_id"], ["user_medications.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "client_id", name="uq_medication_plan_client"),
    )
    op.create_index("ix_medication_plans_user_id", "medication_plans", ["user_id"])
    op.create_index("ix_medication_plans_medication_id", "medication_plans", ["medication_id"])
    op.create_table(
        "medication_plan_sources",
        sa.Column("plan_id", sa.Uuid(), nullable=False),
        sa.Column("source_type", sa.String(40), nullable=False),
        sa.Column("raw_prescription_instruction", sa.Text(), nullable=True),
        sa.Column("confirmed_instruction", sa.Text(), nullable=False),
        sa.Column("confirmed_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["plan_id"], ["medication_plans.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("plan_id"),
    )
    op.create_table(
        "medication_schedules",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("plan_id", sa.Uuid(), nullable=False),
        sa.Column("schedule_type", sa.String(40), nullable=False),
        sa.Column("interval_hours", sa.Integer(), nullable=True),
        sa.Column("interval_anchor", sa.DateTime(timezone=True), nullable=True),
        sa.Column("weekdays", sa.JSON(), nullable=False),
        sa.Column("as_needed", sa.Boolean(), nullable=False),
        sa.Column("active", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["plan_id"], ["medication_plans.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_medication_schedules_plan_id", "medication_schedules", ["plan_id"])
    op.create_table(
        "reminder_times",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("schedule_id", sa.Uuid(), nullable=False),
        sa.Column("minutes_after_midnight", sa.Integer(), nullable=False),
        sa.Column("weekday", sa.Integer(), nullable=True),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["schedule_id"], ["medication_schedules.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_reminder_times_schedule_id", "reminder_times", ["schedule_id"])
    op.create_table(
        "dose_events",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("client_id", sa.String(100), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("plan_id", sa.Uuid(), nullable=False),
        sa.Column("logical_dose_id", sa.String(250), nullable=False),
        sa.Column("scheduled_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("action", sa.String(30), nullable=False),
        sa.Column("recorded_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("source", sa.String(40), nullable=False),
        sa.Column("note", sa.Text(), nullable=True),
        sa.Column("supersedes_event_client_id", sa.String(100), nullable=True),
        sa.Column("revision", sa.Integer(), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["plan_id"], ["medication_plans.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "client_id", name="uq_dose_event_client"),
        sa.UniqueConstraint(
            "user_id", "logical_dose_id", "revision", name="uq_dose_event_revision"
        ),
    )
    op.create_index("ix_dose_events_user_id", "dose_events", ["user_id"])
    op.create_index("ix_dose_events_plan_id", "dose_events", ["plan_id"])
    op.create_index("ix_dose_events_logical_dose_id", "dose_events", ["logical_dose_id"])
    _create_supporting_tables()


def _create_supporting_tables() -> None:
    for name, target in (
        ("medication_notes", "user_medications"),
        ("refill_reminders", "medication_plans"),
    ):
        target_column = "medication_id" if name == "medication_notes" else "plan_id"
        columns: list[sa.Column] = [
            sa.Column("id", sa.Uuid(), nullable=False),
            sa.Column("user_id", sa.Uuid(), nullable=False),
            sa.Column(target_column, sa.Uuid(), nullable=False),
        ]
        if name == "medication_notes":
            columns.extend(
                [
                    sa.Column("note", sa.Text(), nullable=False),
                    sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
                ]
            )
        else:
            columns.extend(
                [
                    sa.Column("reminder_date", sa.Date(), nullable=True),
                    sa.Column("starting_quantity", sa.Float(), nullable=True),
                    sa.Column("quantity_per_taken_dose", sa.Float(), nullable=True),
                    sa.Column("alert_at_remaining", sa.Float(), nullable=True),
                    sa.Column("active", sa.Boolean(), nullable=False),
                ]
            )
        columns.extend(
            [
                sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
                sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
                sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
                sa.ForeignKeyConstraint([target_column], [f"{target}.id"], ondelete="CASCADE"),
                sa.PrimaryKeyConstraint("id"),
            ]
        )
        op.create_table(name, *columns)
        op.create_index(f"ix_{name}_user_id", name, ["user_id"])
        op.create_index(f"ix_{name}_{target_column}", name, [target_column])
    op.create_table(
        "medication_plan_history",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("plan_id", sa.Uuid(), nullable=False),
        sa.Column("action", sa.String(60), nullable=False),
        sa.Column("safe_details", sa.JSON(), nullable=False),
        sa.Column("occurred_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["plan_id"], ["medication_plans.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_medication_plan_history_user_id", "medication_plan_history", ["user_id"])
    op.create_index("ix_medication_plan_history_plan_id", "medication_plan_history", ["plan_id"])
    op.create_table(
        "medication_export_metadata",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("format", sa.String(30), nullable=False),
        sa.Column("included_fields", sa.JSON(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("shared_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_medication_export_metadata_user_id", "medication_export_metadata", ["user_id"]
    )
    op.create_table(
        "medication_privacy_preferences",
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("notification_privacy", sa.String(30), nullable=False),
        sa.Column("retain_prescription_images", sa.Boolean(), nullable=False),
        sa.Column("sync_medication_history", sa.Boolean(), nullable=False),
        sa.Column("hide_medicine_details", sa.Boolean(), nullable=False),
        sa.Column("obscure_app_preview", sa.Boolean(), nullable=False),
        sa.Column("daily_summary_enabled", sa.Boolean(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("user_id"),
    )


def downgrade() -> None:
    for table in [
        "medication_privacy_preferences",
        "medication_export_metadata",
        "medication_plan_history",
        "refill_reminders",
        "medication_notes",
        "dose_events",
        "reminder_times",
        "medication_schedules",
        "medication_plan_sources",
        "medication_plans",
        "user_medications",
    ]:
        op.drop_table(table)
