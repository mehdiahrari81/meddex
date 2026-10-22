import asyncio
from typing import Annotated, Literal

import httpx
from fastapi import APIRouter, Header, HTTPException, Request, Response
from starlette.concurrency import run_in_threadpool
from starlette.requests import ClientDisconnect

from app.api.dependencies import CurrentIdentityDependency, DatabaseDependency, SettingsDependency
from app.core.errors import AppException
from app.core.logging import get_logger
from app.services.gemini_handwriting import transcribe_handwriting
from app.services.medicine_batch_overview import (
    BatchOverview,
    BatchOverviewRequest,
    MedicineBatchOverviewService,
)
from app.services.medicine_overview import (
    MedicineOverview,
    MedicineOverviewRequest,
    MedicineOverviewService,
)
from app.services.prescription_ocr import MAX_IMAGE_BYTES, MODEL_ID, MODEL_REVISION
from app.services.prescription_structuring import (
    PrescriptionStructuringService,
    StructuredPrescription,
    StructurePrescriptionRequest,
)

router = APIRouter(prefix="/prescription-ocr", tags=["prescriptions"])


async def _read_image(request: Request) -> bytes:
    if request.headers.get("content-type", "").split(";")[0] not in {"image/jpeg", "image/png"}:
        raise HTTPException(415, "Use JPEG or PNG images.")
    payload = bytearray()
    try:
        async with asyncio.timeout(65):
            async for chunk in request.stream():
                if len(payload) + len(chunk) > MAX_IMAGE_BYTES:
                    raise HTTPException(413, "Image must be at most 6 MB.")
                payload.extend(chunk)
    except (ClientDisconnect, TimeoutError):
        raise AppException(
            "image_upload_interrupted",
            "The image upload did not finish. Your saved scan can be retried.",
            status_code=408,
        ) from None
    return bytes(payload)


@router.post("/handwriting/gemini")
async def recognize_gemini_handwriting(
    request: Request,
    response: Response,
    identity: CurrentIdentityDependency,
    settings: SettingsDependency,
    cloud_consent: Annotated[Literal["true"], Header(alias="X-Cloud-Consent")],
) -> dict[str, object]:
    response.headers["Cache-Control"] = "no-store"
    payload = await _read_image(request)

    def recognize() -> dict[str, object]:
        with httpx.Client(timeout=30) as client:
            return transcribe_handwriting(settings, client, payload)

    try:
        return await run_in_threadpool(recognize)
    except (httpx.HTTPError, ValueError, RuntimeError, KeyError, TypeError) as error:
        status = error.response.status_code if isinstance(error, httpx.HTTPStatusError) else None
        get_logger().warning(
            "image_read_failed", error_type=type(error).__name__, upstream_status=status
        )
        raise AppException(
            "gemini_limit_reached"
            if status in {402, 429}
            else "gemini_request_timeout"
            if isinstance(error, httpx.TimeoutException)
            else "gemini_temporarily_busy"
            if status in {408, 500, 502, 503, 504}
            else "gemini_handwriting_unavailable",
            "Gemini could not read the image. Your local image is saved; "
            "crop or review it and retry.",
            status_code=503,
        ) from None


@router.post("/medicine-overview", response_model=MedicineOverview)
def medicine_overview(
    payload: MedicineOverviewRequest,
    response: Response,
    identity: CurrentIdentityDependency,
    db: DatabaseDependency,
    settings: SettingsDependency,
) -> MedicineOverview:
    response.headers["Cache-Control"] = "no-store"
    try:
        return MedicineOverviewService(db, settings).overview(identity.user.id, payload)
    except (httpx.HTTPError, ValueError, RuntimeError, KeyError, TypeError) as error:
        get_logger().warning("overview_failed", error_type=type(error).__name__)
        raise AppException(
            "medicine_information_unavailable",
            "Medicine information is temporarily unavailable. Please retry.",
            status_code=503,
        ) from None


@router.post("/medicine-overviews", response_model=BatchOverview)
def medicine_overviews(
    payload: BatchOverviewRequest,
    response: Response,
    identity: CurrentIdentityDependency,
    db: DatabaseDependency,
    settings: SettingsDependency,
) -> BatchOverview:
    response.headers["Cache-Control"] = "no-store"
    return MedicineBatchOverviewService(db, settings).overview(identity.user.id, payload)


@router.post("/structure", response_model=StructuredPrescription)
def structure_prescription(
    payload: StructurePrescriptionRequest,
    response: Response,
    identity: CurrentIdentityDependency,
    settings: SettingsDependency,
) -> StructuredPrescription:
    response.headers["Cache-Control"] = "no-store"
    try:
        with httpx.Client(timeout=30) as client:
            return PrescriptionStructuringService(settings, client).structure(payload)
    except httpx.HTTPStatusError as error:
        status = error.response.status_code
        get_logger().warning("structure_failed", error_type="upstream_http", upstream_status=status)
        if error.response.status_code in {402, 429}:
            raise AppException(
                "gemini_limit_reached",
                "Gemini's limit was reached. Retry later or enter medicines manually.",
                status_code=503,
            ) from None
        raise AppException(
            "gemini_temporarily_busy"
            if status in {408, 500, 502, 503, 504}
            else "medicine_extraction_unavailable",
            "Medicine extraction is unavailable. Your OCR text remains on your device.",
            status_code=503,
        ) from None
    except httpx.TimeoutException:
        raise AppException(
            "gemini_request_timeout",
            "Gemini did not respond in time. Your recognized text is saved; retry later.",
            status_code=503,
        ) from None
    except (httpx.HTTPError, ValueError, RuntimeError, KeyError, TypeError) as error:
        get_logger().warning("structure_failed", error_type=type(error).__name__)
        raise AppException(
            "medicine_extraction_unverified",
            "Medicines could not be reliably separated. "
            "Review the OCR text or enter medicines manually.",
            status_code=503,
        ) from None


@router.post("/handwriting")
async def recognize_handwriting(
    request: Request,
    response: Response,
    identity: CurrentIdentityDependency,
) -> dict[str, object]:
    response.headers["Cache-Control"] = "no-store"
    payload = await _read_image(request)
    lines = await run_in_threadpool(
        request.app.state.handwriting_recognizer.recognize, bytes(payload)
    )
    return {
        "text": "\n".join(line.text for line in lines),
        "lines": [
            {"text": line.text, "region": line.region, "confidence": None, "requires_review": True}
            for line in lines
        ],
        "model": MODEL_ID,
        "revision": MODEL_REVISION,
        "requires_review": True,
        "warning": "Unverified OCR. Check every medicine name and dose against the image.",
    }
