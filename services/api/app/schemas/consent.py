from datetime import datetime
from uuid import UUID

from pydantic import Field

from app.schemas.common import StrictSchema


class ConsentCreate(StrictSchema):
    version: int = Field(ge=1)
    locale: str = Field(min_length=2, max_length=12)


class ConsentRead(StrictSchema):
    id: UUID
    user_id: UUID
    version: int
    locale: str
    accepted_at: datetime
