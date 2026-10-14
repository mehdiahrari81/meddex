from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.models import AuthSession, ConsentRecord, PasswordResetToken, User


class UserRepository:
    def __init__(self, db: Session) -> None:
        self.db = db

    def by_email(self, email: str) -> User | None:
        return self.db.scalar(
            select(User).options(joinedload(User.profile)).where(User.email == email)
        )

    def by_id(self, user_id: UUID) -> User | None:
        return self.db.scalar(
            select(User).options(joinedload(User.profile)).where(User.id == user_id)
        )

    def add(self, user: User) -> None:
        self.db.add(user)


class SessionRepository:
    def __init__(self, db: Session) -> None:
        self.db = db

    def by_id(self, session_id: UUID) -> AuthSession | None:
        return self.db.get(AuthSession, session_id)

    def add(self, auth_session: AuthSession) -> None:
        self.db.add(auth_session)


class ConsentRepository:
    def __init__(self, db: Session) -> None:
        self.db = db

    def by_user_and_version(self, user_id: UUID, version: int) -> ConsentRecord | None:
        return self.db.scalar(
            select(ConsentRecord).where(
                ConsentRecord.user_id == user_id,
                ConsentRecord.version == version,
            )
        )


class PasswordResetRepository:
    def __init__(self, db: Session) -> None:
        self.db = db

    def by_id(self, token_id: UUID) -> PasswordResetToken | None:
        return self.db.get(PasswordResetToken, token_id)
