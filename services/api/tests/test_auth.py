from fastapi.testclient import TestClient

from tests.conftest import CapturingEmailSender, auth_headers


def test_registration_returns_persistent_session(client: TestClient) -> None:
    response = client.post(
        "/api/v1/auth/register",
        json={
            "email": "New.Person@Example.com",
            "password": "SecurePassword!123",
            "display_name": "New Person",
        },
    )
    assert response.status_code == 201
    payload = response.json()
    assert payload["token_type"] == "bearer"
    assert payload["access_token"]
    assert payload["refresh_token"]
    assert payload["access_token"] != payload["refresh_token"]

    user = client.get("/api/v1/users/me", headers=auth_headers(payload["access_token"]))
    assert user.status_code == 200
    assert user.json()["email"] == "new.person@example.com"


def test_registration_validation_rejects_weak_password(client: TestClient) -> None:
    response = client.post(
        "/api/v1/auth/register",
        json={"email": "person@example.com", "password": "password", "display_name": "P"},
    )
    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"
    assert "request_id" in response.json()["error"]


def test_registration_rejects_duplicate_email(
    client: TestClient, registered: dict[str, str]
) -> None:
    response = client.post(
        "/api/v1/auth/register",
        json={
            "email": "PERSON@example.com",
            "password": "AnotherPassword!123",
            "display_name": "Duplicate",
        },
    )
    assert response.status_code == 409
    assert response.json()["error"]["code"] == "email_exists"


def test_login_and_incorrect_credentials(client: TestClient, registered: dict[str, str]) -> None:
    success = client.post(
        "/api/v1/auth/login",
        json={"email": "person@example.com", "password": "SecurePassword!123"},
    )
    assert success.status_code == 200

    failure = client.post(
        "/api/v1/auth/login",
        json={"email": "person@example.com", "password": "WrongPassword!123"},
    )
    assert failure.status_code == 401
    assert failure.json()["error"]["code"] == "invalid_credentials"


def test_refresh_rotates_token_and_reuse_revokes_session(
    client: TestClient, registered: dict[str, str]
) -> None:
    old_refresh = registered["refresh_token"]
    refreshed = client.post("/api/v1/auth/refresh", json={"refresh_token": old_refresh})
    assert refreshed.status_code == 200
    rotated = refreshed.json()
    assert rotated["refresh_token"] != old_refresh

    reuse = client.post("/api/v1/auth/refresh", json={"refresh_token": old_refresh})
    assert reuse.status_code == 401
    assert reuse.json()["error"]["code"] == "session_expired"

    revoked_rotation = client.post(
        "/api/v1/auth/refresh", json={"refresh_token": rotated["refresh_token"]}
    )
    assert revoked_rotation.status_code == 401


def test_logout_revokes_current_session(client: TestClient, registered: dict[str, str]) -> None:
    response = client.post("/api/v1/auth/logout", headers=auth_headers(registered["access_token"]))
    assert response.status_code == 204

    protected = client.get("/api/v1/users/me", headers=auth_headers(registered["access_token"]))
    assert protected.status_code == 401

    refresh = client.post(
        "/api/v1/auth/refresh", json={"refresh_token": registered["refresh_token"]}
    )
    assert refresh.status_code == 401


def test_password_reset_revokes_existing_sessions(
    client: TestClient,
    registered: dict[str, str],
    email_sender: CapturingEmailSender,
) -> None:
    request = client.post("/api/v1/auth/password/forgot", json={"email": "person@example.com"})
    assert request.status_code == 200
    token = email_sender.reset_tokens["person@example.com"]

    reset = client.post(
        "/api/v1/auth/password/reset",
        json={"token": token, "new_password": "ChangedPassword!123"},
    )
    assert reset.status_code == 200

    old_session = client.get("/api/v1/users/me", headers=auth_headers(registered["access_token"]))
    assert old_session.status_code == 401
    login = client.post(
        "/api/v1/auth/login",
        json={"email": "person@example.com", "password": "ChangedPassword!123"},
    )
    assert login.status_code == 200


def test_forgot_password_does_not_disclose_account_existence(client: TestClient) -> None:
    response = client.post("/api/v1/auth/password/forgot", json={"email": "missing@example.com"})
    assert response.status_code == 200
    assert "If an account exists" in response.json()["message"]
