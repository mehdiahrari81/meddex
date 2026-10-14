from fastapi.testclient import TestClient

from tests.conftest import auth_headers


def test_protected_endpoint_requires_authorization(client: TestClient) -> None:
    response = client.get("/api/v1/users/me/profile")
    assert response.status_code == 401
    assert response.json()["error"]["code"] == "session_expired"


def test_profile_read_and_update(client: TestClient, registered: dict[str, str]) -> None:
    headers = auth_headers(registered["access_token"])
    initial = client.get("/api/v1/users/me/profile", headers=headers)
    assert initial.status_code == 200
    assert initial.json()["user_mode"] == "patient"
    assert initial.json()["analytics_enabled"] is False

    updated = client.patch(
        "/api/v1/users/me/profile",
        headers=headers,
        json={
            "display_name": "Student Person",
            "user_mode": "student",
            "explanation_level": "technical",
            "preferred_language": "ur",
            "theme": "dark",
            "text_scale": 1.3,
            "reduced_motion": True,
        },
    )
    assert updated.status_code == 200
    payload = updated.json()
    assert payload["display_name"] == "Student Person"
    assert payload["user_mode"] == "student"
    assert payload["preferred_language"] == "ur"


def test_profile_rejects_unknown_fields(client: TestClient, registered: dict[str, str]) -> None:
    response = client.patch(
        "/api/v1/users/me/profile",
        headers=auth_headers(registered["access_token"]),
        json={"diagnosis": "must not be collected"},
    )
    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


def test_consent_recording_updates_profile(client: TestClient, registered: dict[str, str]) -> None:
    headers = auth_headers(registered["access_token"])
    response = client.post("/api/v1/consents", headers=headers, json={"version": 1, "locale": "ur"})
    assert response.status_code == 201
    assert response.json()["version"] == 1

    profile = client.get("/api/v1/users/me/profile", headers=headers)
    assert profile.json()["consent_version"] == 1

    duplicate = client.post(
        "/api/v1/consents", headers=headers, json={"version": 1, "locale": "ur"}
    )
    assert duplicate.status_code == 409


def test_malformed_json_has_safe_structured_error(client: TestClient) -> None:
    response = client.post(
        "/api/v1/auth/login",
        content="{not-json",
        headers={"Content-Type": "application/json"},
    )
    assert response.status_code == 422
    payload = response.json()["error"]
    assert payload["code"] == "validation_error"
    assert "traceback" not in response.text.lower()


def test_account_deletion_removes_access(client: TestClient, registered: dict[str, str]) -> None:
    headers = auth_headers(registered["access_token"])
    response = client.delete("/api/v1/users/me", headers=headers)
    assert response.status_code == 204
    assert client.get("/api/v1/users/me", headers=headers).status_code == 401
