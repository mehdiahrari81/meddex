from fastapi import APIRouter, status

from app.api.dependencies import CurrentIdentityDependency, DatabaseDependency
from app.schemas.profile import ProfileRead, ProfileUpdate, UserRead
from app.services.profile import ProfileService

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me", response_model=UserRead)
def current_user(identity: CurrentIdentityDependency) -> UserRead:
    user = identity.user
    return UserRead(
        id=user.id,
        email=user.email,
        display_name=user.profile.display_name,
        created_at=user.created_at,
    )


@router.get("/me/profile", response_model=ProfileRead)
def read_profile(identity: CurrentIdentityDependency, db: DatabaseDependency) -> ProfileRead:
    return ProfileService(db).read(identity.user)


@router.patch("/me/profile", response_model=ProfileRead)
def update_profile(
    changes: ProfileUpdate,
    identity: CurrentIdentityDependency,
    db: DatabaseDependency,
) -> ProfileRead:
    return ProfileService(db).update(identity.user, changes)


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
def delete_account(identity: CurrentIdentityDependency, db: DatabaseDependency) -> None:
    ProfileService(db).delete_account(identity.user)
