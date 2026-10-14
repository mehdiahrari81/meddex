"""module 3 prescriptions

Revision ID: 0003_module_3
Revises: 0002_module_2
Create Date: 2026-08-13 02:10:00
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0003_module_3"
down_revision: str | None = "0002_module_2"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "prescriptions",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("client_id", sa.String(length=100), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("source_type", sa.String(length=30), nullable=False),
        sa.Column("capture_date", sa.DateTime(timezone=True), nullable=False),
        sa.Column("parser_version", sa.String(length=80), nullable=False),
        sa.Column("ocr_provider", sa.String(length=100), nullable=True),
        sa.Column("ocr_provider_version", sa.String(length=80), nullable=True),
        sa.Column("page_count", sa.Integer(), nullable=False),
        sa.Column("verification_state", sa.String(length=40), nullable=False),
        sa.Column("user_confirmed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("revision", sa.Integer(), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "client_id", name="uq_prescription_client_id"),
    )
    op.create_index("ix_prescriptions_user_id", "prescriptions", ["user_id"])
    op.create_index("ix_prescriptions_verification_state", "prescriptions", ["verification_state"])
    op.create_index("ix_prescriptions_deleted_at", "prescriptions", ["deleted_at"])
    op.create_table(
        "prescription_items",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("client_id", sa.String(length=100), nullable=False),
        sa.Column("prescription_id", sa.Uuid(), nullable=False),
        sa.Column("state", sa.String(length=40), nullable=False),
        sa.Column("page_number", sa.Integer(), nullable=False),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.Column("fields", sa.JSON(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["prescription_id"], ["prescriptions.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("prescription_id", "client_id", name="uq_prescription_item_client_id"),
    )
    op.create_index(
        "ix_prescription_items_prescription_id", "prescription_items", ["prescription_id"]
    )
    op.create_table(
        "prescription_reports",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("prescription_id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("reason", sa.String(length=50), nullable=False),
        sa.Column("note", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["prescription_id"], ["prescriptions.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_prescription_reports_prescription_id",
        "prescription_reports",
        ["prescription_id"],
    )
    op.create_index("ix_prescription_reports_user_id", "prescription_reports", ["user_id"])
    op.create_table(
        "barcode_scans",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("client_id", sa.String(length=100), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("format", sa.String(length=50), nullable=False),
        sa.Column("raw_value", sa.String(length=500), nullable=False),
        sa.Column("source", sa.String(length=50), nullable=False),
        sa.Column("scanned_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("user_confirmed", sa.Boolean(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "client_id", name="uq_barcode_client_id"),
    )
    op.create_index("ix_barcode_scans_user_id", "barcode_scans", ["user_id"])


def downgrade() -> None:
    op.drop_index("ix_barcode_scans_user_id", table_name="barcode_scans")
    op.drop_table("barcode_scans")
    op.drop_index("ix_prescription_reports_user_id", table_name="prescription_reports")
    op.drop_index("ix_prescription_reports_prescription_id", table_name="prescription_reports")
    op.drop_table("prescription_reports")
    op.drop_index("ix_prescription_items_prescription_id", table_name="prescription_items")
    op.drop_table("prescription_items")
    op.drop_index("ix_prescriptions_deleted_at", table_name="prescriptions")
    op.drop_index("ix_prescriptions_verification_state", table_name="prescriptions")
    op.drop_index("ix_prescriptions_user_id", table_name="prescriptions")
    op.drop_table("prescriptions")
