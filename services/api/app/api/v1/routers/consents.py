from fastapi import APIRouter, status

from app.api.dependencies import CurrentIdentityDependency, DatabaseDependency
from app.schemas.consent import ConsentCreate, ConsentRead
from app.services.profile import ProfileService

router = APIRouter(prefix="/consents", tags=["consents"])


@router.post("", response_model=ConsentRead, status_code=status.HTTP_201_CREATED)
def record_consent(
    consent: ConsentCreate,
    identity: CurrentIdentityDependency,
    db: DatabaseDependency,
) -> ConsentRead:
    record = ProfileService(db).record_consent(identity.user, consent)
    return ConsentRead.model_validate(record)
