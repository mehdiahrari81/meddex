from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import JSON, Boolean, DateTime, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.time import utc_now
from app.db.base import Base


class Prescription(Base):
    __tablename__ = "prescriptions"
    __table_args__ = (UniqueConstraint("user_id", "client_id", name="uq_prescription_client_id"),)

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    client_id: Mapped[str] = mapped_column(String(100))
    user_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    source_type: Mapped[str] = mapped_column(String(30))
    capture_date: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    parser_version: Mapped[str] = mapped_column(String(80))
    ocr_provider: Mapped[str | None] = mapped_column(String(100))
    ocr_provider_version: Mapped[str | None] = mapped_column(String(80))
    page_count: Mapped[int] = mapped_column(Integer, default=0)
    verification_state: Mapped[str] = mapped_column(String(40), index=True)
    user_confirmed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    revision: Mapped[int] = mapped_column(Integer, default=1)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)

    items: Mapped[list["PrescriptionItem"]] = relationship(
        back_populates="prescription",
        cascade="all, delete-orphan",
        passive_deletes=True,
        order_by="PrescriptionItem.position",
    )


class PrescriptionItem(Base):
    __tablename__ = "prescription_items"
    __table_args__ = (
        UniqueConstraint("prescription_id", "client_id", name="uq_prescription_item_client_id"),
    )

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    client_id: Mapped[str] = mapped_column(String(100))
    prescription_id: Mapped[UUID] = mapped_column(
        ForeignKey("prescriptions.id", ondelete="CASCADE"), index=True
    )
    state: Mapped[str] = mapped_column(String(40))
    page_number: Mapped[int] = mapped_column(Integer)
    position: Mapped[int] = mapped_column(Integer)
    fields: Mapped[list[dict[str, object]]] = mapped_column(JSON, default=list)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)

    prescription: Mapped[Prescription] = relationship(back_populates="items")


class PrescriptionReport(Base):
    __tablename__ = "prescription_reports"

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    prescription_id: Mapped[UUID] = mapped_column(
        ForeignKey("prescriptions.id", ondelete="CASCADE"), index=True
    )
    user_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    reason: Mapped[str] = mapped_column(String(50))
    note: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)


class BarcodeScan(Base):
    __tablename__ = "barcode_scans"
    __table_args__ = (UniqueConstraint("user_id", "client_id", name="uq_barcode_client_id"),)

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    client_id: Mapped[str] = mapped_column(String(100))
    user_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    format: Mapped[str] = mapped_column(String(50))
    raw_value: Mapped[str] = mapped_column(String(500))
    source: Mapped[str] = mapped_column(String(50))
    scanned_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    user_confirmed: Mapped[bool] = mapped_column(Boolean, default=False)
