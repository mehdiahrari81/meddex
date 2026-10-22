from fastapi import APIRouter

from app.api.v1.routers import (
    admin,
    auth,
    consents,
    content,
    health,
    intelligence,
    learning,
    medications,
    module2_user,
    prescription_ocr,
    prescriptions,
    terminology,
    users,
)

api_router = APIRouter()
api_router.include_router(admin.router)
api_router.include_router(health.router)
api_router.include_router(intelligence.router)
api_router.include_router(auth.router)
api_router.include_router(users.router)
api_router.include_router(consents.router)
api_router.include_router(terminology.router)
api_router.include_router(learning.router)
api_router.include_router(content.router)
api_router.include_router(module2_user.router)
api_router.include_router(prescriptions.router)
api_router.include_router(prescription_ocr.router)
api_router.include_router(medications.router)
