from collections.abc import Generator
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.core.config import Settings
from app.db.base import Base
from app.factory import create_app
from app.models import AdminPermission, AdminRole, AdminRolePermission, FeatureFlag
from app.services.content_import import ContentImporter
from app.services.email import DeliveryResult, EmailSender


@pytest.fixture(autouse=True)
def isolated_scan_availability(monkeypatch):
    from app.providers.ai import scan_model_cooldown, shared_cooldown

    # Unit tests must never inherit the developer's actual Groq credential.
    monkeypatch.setenv("MEDIEXPLAIN_GROQ_API_KEY", "")
    monkeypatch.setenv("MEDIEXPLAIN_ADMIN_ALLOW_LOCAL_SELF_REVIEW", "false")
    shared_cooldown.cache_clear()
    scan_model_cooldown.cache_clear()
    # Network retries are exercised without real waiting in unit tests.
    monkeypatch.setattr("app.providers.ai.time.sleep", lambda _: None)
    yield
    scan_model_cooldown.cache_clear()
    shared_cooldown.cache_clear()


class CapturingEmailSender(EmailSender):
    def __init__(self) -> None:
        self.reset_tokens: dict[str, str] = {}

    def send_password_reset(self, email: str, token: str) -> DeliveryResult:
        self.reset_tokens[email] = token
        return DeliveryResult(accepted_for_delivery=True, provider_reference="test-delivery")


@pytest.fixture
def email_sender() -> CapturingEmailSender:
    return CapturingEmailSender()


@pytest.fixture
def client(email_sender: CapturingEmailSender) -> Generator[TestClient, None, None]:
    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    dataset = (
        Path(__file__).resolve().parents[3]
        / "apps"
        / "mobile"
        / "assets"
        / "terminology"
        / "starter_dataset_v1.json"
    )
    with Session(engine) as seed_db:
        ContentImporter(seed_db).import_path(dataset)
        _seed_governance(seed_db)
    settings = Settings(
        environment="testing",
        database_url="sqlite+pysqlite:///:memory:",
        secret_key="test-secret-that-is-long-enough-for-signing",
        allowed_origins=["http://testserver"],
        rate_limit_per_minute=1_000,
    )
    app = create_app(settings, engine=engine, email_sender=email_sender)
    with TestClient(app, raise_server_exceptions=False) as test_client:
        yield test_client
    Base.metadata.drop_all(engine)
    engine.dispose()


def _seed_governance(db: Session) -> None:
    permissions = [
        "terminology.read",
        "terminology.edit",
        "terminology.review",
        "content.read",
        "content.edit",
        "content.review",
        "content.publish",
        "translation.review",
        "reports.review",
        "sources.manage",
        "users.support_read",
        "audit.read",
        "system.read",
        "system.manage",
    ]
    grants = {
        "SUPER_ADMIN": permissions,
        "PLATFORM_ADMIN": [
            "content.read",
            "reports.review",
            "sources.manage",
            "users.support_read",
            "audit.read",
            "system.read",
            "system.manage",
        ],
        "CONTENT_EDITOR": [
            "terminology.read",
            "terminology.edit",
            "content.read",
            "content.edit",
        ],
        "CONTENT_REVIEWER": [
            "terminology.read",
            "terminology.review",
            "content.read",
            "content.review",
            "content.publish",
            "translation.review",
            "reports.review",
        ],
        "SUPPORT_READ_ONLY": ["reports.review", "users.support_read", "system.read"],
    }
    db.add_all(
        AdminPermission(code=permission, description=permission.replace(".", " ").title())
        for permission in permissions
    )
    db.flush()
    for role_name, role_permissions in grants.items():
        role = AdminRole(name=role_name, description=role_name.replace("_", " ").title())
        db.add(role)
        db.flush()
        db.add_all(
            AdminRolePermission(role_id=role.id, permission_code=permission)
            for permission in role_permissions
        )
    db.add_all(
        [
            FeatureFlag(key="ai_assistant", enabled=False, description="Grounded AI answers"),
            FeatureFlag(
                key="interaction_checking",
                enabled=False,
                description="Validated interaction provider",
            ),
        ]
    )
    db.commit()


@pytest.fixture
def registered(client: TestClient) -> dict[str, str]:
    response = client.post(
        "/api/v1/auth/register",
        json={
            "email": "person@example.com",
            "password": "SecurePassword!123",
            "display_name": "Test Person",
        },
    )
    assert response.status_code == 201
    return response.json()


def auth_headers(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}
