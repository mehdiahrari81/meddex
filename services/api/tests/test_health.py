from fastapi.testclient import TestClient


def test_health_endpoint(client: TestClient) -> None:
    response = client.get("/api/v1/health", headers={"X-Request-ID": "health-test"})
    assert response.status_code == 200
    assert response.json() == {"status": "healthy"}
    assert response.headers["X-Request-ID"] == "health-test"


def test_readiness_endpoint_checks_database(client: TestClient) -> None:
    response = client.get("/api/v1/ready")
    assert response.status_code == 200
    assert response.json() == {"status": "ready"}


def test_openapi_is_versioned(client: TestClient) -> None:
    schema = client.get("/openapi.json").json()
    assert "/api/v1/auth/login" in schema["paths"]
    assert "/api/v1/users/me/profile" in schema["paths"]
    assert "/api/v1/medication-intelligence/ai/answer" in schema["paths"]


def test_request_metrics_are_permission_gated_and_do_not_label_identifiers(
    client: TestClient, registered: dict[str, str]
) -> None:
    from tests.conftest import auth_headers

    assert (
        client.get(
            "/api/v1/admin/metrics", headers=auth_headers(registered["access_token"])
        ).status_code
        == 401
    )
