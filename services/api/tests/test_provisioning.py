import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select

from app.cli import provision_admin
from app.models import AdminMembership


def test_provisioned_administrator_can_sign_in(client: TestClient) -> None:
    with client.app.state.session_factory() as db:
        provision_admin(
            db,
            client.app.state.settings,
            email="operator@example.com",
            password="SecurePassword!123",
            display_name="Local Operator",
            role_name="SUPER_ADMIN",
        )
    response = client.post(
        "/api/v1/admin/auth/login",
        json={
            "email": "operator@example.com",
            "password": "SecurePassword!123",
            "mfa_code": None,
        },
    )
    assert response.status_code == 200
    assert "sources.manage" in response.json()["permissions"]


def test_provisioning_does_not_overwrite_existing_membership(client: TestClient) -> None:
    with client.app.state.session_factory() as db:
        arguments = dict(
            email="operator2@example.com",
            password="SecurePassword!123",
            display_name="Operator",
            role_name="CONTENT_EDITOR",
        )
        provision_admin(db, client.app.state.settings, **arguments)
        with pytest.raises(ValueError, match="already has"):
            provision_admin(db, client.app.state.settings, **arguments)
        db.rollback()
        assert len(db.scalars(select(AdminMembership)).all()) == 1


def test_invalid_password_is_never_in_provisioning_error(client: TestClient) -> None:
    with client.app.state.session_factory() as db:
        with pytest.raises(ValueError) as failure:
            provision_admin(
                db,
                client.app.state.settings,
                email="operator3@example.com",
                password="private-invalid-password",
                display_name="Operator",
                role_name="SUPER_ADMIN",
            )
        assert "private-invalid-password" not in str(failure.value)
