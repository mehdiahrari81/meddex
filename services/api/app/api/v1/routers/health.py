import base64
from typing import Annotated

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from fastapi import APIRouter, HTTPException, Query, Response
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

from app.api.dependencies import DatabaseDependency, SettingsDependency
from app.core.errors import AppException

router = APIRouter(tags=["health"])


@router.get("/local-server-identity", include_in_schema=False)
def local_server_identity(
    challenge: Annotated[str, Query(pattern=r"^[0-9a-f]{64}$")],
    response: Response,
    settings: SettingsDependency,
) -> dict[str, str]:
    if settings.environment == "production" or not settings.local_server_private_key:
        raise HTTPException(404)
    private = ec.derive_private_key(
        int(settings.local_server_private_key.get_secret_value(), 16), ec.SECP256R1()
    )
    public = private.public_key().public_bytes(
        serialization.Encoding.DER, serialization.PublicFormat.SubjectPublicKeyInfo
    )
    signature = private.sign(
        ("mediexplain-local-server-v1\n" + challenge).encode(), ec.ECDSA(hashes.SHA256())
    )
    response.headers["Cache-Control"] = "no-store"
    return {
        "public_key": base64.b64encode(public).decode(),
        "signature": base64.b64encode(signature).decode(),
    }


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
