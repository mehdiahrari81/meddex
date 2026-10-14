from typing import Any

from pydantic import BaseModel, ConfigDict


class StrictSchema(BaseModel):
    model_config = ConfigDict(extra="forbid", from_attributes=True)


class ErrorDetail(StrictSchema):
    code: str
    message: str
    request_id: str
    details: dict[str, Any] | list[Any] | None = None


class ErrorResponse(StrictSchema):
    error: ErrorDetail


class MessageResponse(StrictSchema):
    message: str
