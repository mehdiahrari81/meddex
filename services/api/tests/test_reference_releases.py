import json
from pathlib import Path

from fastapi.testclient import TestClient

from tests.test_admin import _admin, _headers


def _document() -> dict:
    return json.loads(
        (
            Path(__file__).resolve().parents[3]
            / "apps/mobile/assets/terminology/starter_dataset_v1.json"
        ).read_text()
    )


def test_reference_publication_updates_canonical_api_and_download(client: TestClient) -> None:
    editor = _headers(
        _admin(client, "CONTENT_EDITOR", "release-editor@example.com")["access_token"]
    )
    reviewer = _headers(
        _admin(client, "CONTENT_REVIEWER", "release-reviewer@example.com")["access_token"]
    )
    document = _document()
    document["dataset_version"] = "browser-release-v2"
    assert client.get("/api/v1/content/dataset").status_code == 404
    created = client.post(
        "/api/v1/admin/content",
        headers=editor,
        json={
            "stable_id": "reference.release",
            "content_type": "dataset",
            "content": document,
            "source_metadata": {"provider": "reviewed fixture"},
            "change_reason": "Reference release test",
        },
    )
    assert created.status_code == 201
    revisions = client.get("/api/v1/admin/content/reference.release/revisions", headers=reviewer)
    assert revisions.status_code == 200
    assert revisions.json()[0]["content"] == document
    assert revisions.json()[0]["source_metadata"]["provider"] == "reviewed fixture"
    assert client.get("/api/v1/admin/content/reference.release/revisions").status_code == 401
    assert client.get("/api/v1/content/dataset").status_code == 404
    for action, headers in (
        ("submit_review", editor),
        ("approve", reviewer),
        ("publish", reviewer),
    ):
        result = client.post(
            "/api/v1/admin/content/reference.release/workflow",
            headers=headers,
            json={
                "action": action,
                "reason": "Reviewed source data",
                "confirmation": "reference.release",
            },
        )
        assert result.status_code == 200, result.text
    assert client.get("/api/v1/content/dataset").json() == document
    assert client.get("/api/v1/content/version").json()["dataset_version"] == "browser-release-v2"

    # A subsequent unpublished revision must not replace the active release.
    document["dataset_version"] = "draft-v3"
    assert (
        client.post(
            "/api/v1/admin/content",
            headers=editor,
            json={
                "stable_id": "reference.release",
                "content_type": "dataset",
                "content": document,
                "source_metadata": {"provider": "reviewed fixture"},
                "change_reason": "Next revision",
            },
        ).status_code
        == 201
    )
    assert client.get("/api/v1/content/dataset").json()["dataset_version"] == "browser-release-v2"

    client.app.state.settings.environment = "production"
    assert client.get("/api/v1/content/dataset").status_code == 404


def test_reference_draft_requires_complete_validated_dataset(client: TestClient) -> None:
    editor = _headers(
        _admin(client, "CONTENT_EDITOR", "invalid-release@example.com")["access_token"]
    )
    response = client.post(
        "/api/v1/admin/content",
        headers=editor,
        json={
            "stable_id": "reference.invalid",
            "content_type": "dataset",
            "content": {"title": "Invalid"},
            "source_metadata": {},
            "change_reason": "Invalid dataset fixture",
        },
    )
    assert response.status_code == 400
    assert client.get("/api/v1/content/dataset").status_code == 404


def test_unapproved_reference_cannot_be_published_in_production(client: TestClient) -> None:
    editor = _headers(
        _admin(client, "CONTENT_EDITOR", "production-editor@example.com")["access_token"]
    )
    reviewer = _headers(
        _admin(client, "CONTENT_REVIEWER", "production-reviewer@example.com")["access_token"]
    )
    document = _document()
    document["dataset_version"] = "unapproved-release-v2"
    response = client.post(
        "/api/v1/admin/content",
        headers=editor,
        json={
            "stable_id": "reference.production",
            "content_type": "dataset",
            "content": document,
            "source_metadata": {},
            "change_reason": "Production guard fixture",
        },
    )
    assert response.status_code == 201
    for action, headers in (("submit_review", editor), ("approve", reviewer)):
        assert (
            client.post(
                "/api/v1/admin/content/reference.production/workflow",
                headers=headers,
                json={
                    "action": action,
                    "reason": "Independent review",
                    "confirmation": "reference.production",
                },
            ).status_code
            == 200
        )
    client.app.state.settings.environment = "production"
    denied = client.post(
        "/api/v1/admin/content/reference.production/workflow",
        headers=reviewer,
        json={
            "action": "publish",
            "reason": "Publish fixture",
            "confirmation": "reference.production",
        },
    )
    assert denied.status_code == 409
    assert "production-approved" in denied.json()["detail"]
