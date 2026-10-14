from uuid import uuid4

from fastapi.testclient import TestClient

from tests.conftest import auth_headers


def test_session_list_and_remote_revocation(client: TestClient, registered: dict[str, str]) -> None:
    other = client.post(
        "/api/v1/auth/login",
        json={"email": "person@example.com", "password": "SecurePassword!123"},
    ).json()
    headers = auth_headers(registered["access_token"])
    sessions = client.get("/api/v1/auth/sessions", headers=headers)
    assert sessions.status_code == 200
    assert len(sessions.json()) == 2
    assert sum(row["is_current"] for row in sessions.json()) == 1
    assert all("refresh_token_hash" not in row for row in sessions.json())
    assert (
        client.delete(f"/api/v1/auth/sessions/{other['session_id']}", headers=headers).status_code
        == 204
    )
    assert (
        client.get("/api/v1/users/me", headers=auth_headers(other["access_token"])).status_code
        == 401
    )
    assert len(client.get("/api/v1/auth/sessions", headers=headers).json()) == 1


def test_sessions_are_owner_scoped(client: TestClient, registered: dict[str, str]) -> None:
    other = client.post(
        "/api/v1/auth/register",
        json={
            "email": "other@example.com",
            "password": "SecurePassword!123",
            "display_name": "Other",
        },
    ).json()
    headers = auth_headers(registered["access_token"])
    for session_id in (other["session_id"], str(uuid4())):
        assert (
            client.delete(f"/api/v1/auth/sessions/{session_id}", headers=headers).status_code == 404
        )
    assert (
        client.get("/api/v1/users/me", headers=auth_headers(other["access_token"])).status_code
        == 200
    )


def test_current_session_can_be_revoked(client: TestClient, registered: dict[str, str]) -> None:
    headers = auth_headers(registered["access_token"])
    assert (
        client.delete(
            f"/api/v1/auth/sessions/{registered['session_id']}", headers=headers
        ).status_code
        == 204
    )
    assert client.get("/api/v1/auth/sessions", headers=headers).status_code == 401
