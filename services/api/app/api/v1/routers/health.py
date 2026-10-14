from fastapi import APIRouter
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

from app.api.dependencies import DatabaseDependency
from app.core.errors import AppException

router = APIRouter(tags=["health"])


@router.get("/health", summary="Liveness check")
def health() -> dict[str, str]:
    return {"status": "healthy"}


@router.get("/ready", summary="Readiness check")
def ready(db: DatabaseDependency) -> dict[str, str]:
    try:
        db.execute(text("SELECT 1"))
    except SQLAlchemyError as error:
        raise AppException("not_ready", "The service is not ready.", status_code=503) from error
    return {"status": "ready"}
