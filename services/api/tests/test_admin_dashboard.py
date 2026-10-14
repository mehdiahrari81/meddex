import json
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import func, select

from app.models import ContentImportJob, GovernedContent, User
from app.services.demo_data import seed_demo_data
from tests.test_admin import _admin, _headers


def _dataset() -> dict:
    return json.loads(
        (
            Path(__file__).resolve().parents[3]
            / "apps/mobile/assets/terminology/starter_dataset_v1.json"
        ).read_text()
    )


def test_dashboard_totals_scope_and_periods(client: TestClient) -> None:
    admin = _admin(client, "SUPER_ADMIN", "dashboard@example.com")
    with client.app.state.session_factory() as db:
        assert seed_demo_data(
            db, client.app.state.settings, "dashboard@example.com", _dataset()
        ) == {"content": 24, "reports": 6, "imports": 2}
    response = client.get(
        "/api/v1/admin/dashboard?days=14", headers=_headers(admin["access_token"])
    )
    assert response.status_code == 200
    result = response.json()
    assert result["content"]["total"] == 24
    assert result["demo_records"] == 24
    assert len(result["recent_content"]) == 12
    assert result["reports"]["states"] == {"in_review": 2, "open": 3, "resolved": 1}
    assert sum(result["content"]["states"].values()) == 24
    assert len(result["editorial_activity"]) == 14
    assert sum(day["count"] for day in result["editorial_activity"]) == 24
    assert all(row["is_demo"] for row in result["recent_content"])
    assert (
        client.get(
            "/api/v1/admin/dashboard?days=90", headers=_headers(admin["access_token"])
        ).status_code
        == 422
    )
    support = _admin(client, "SUPPORT_READ_ONLY", "dashboard-support@example.com")
    limited = client.get(
        "/api/v1/admin/dashboard", headers=_headers(support["access_token"])
    ).json()
    assert limited["content"] is None
    assert limited["recent_content"] == []
    assert limited["editorial_activity"] == []
    assert limited["recent_activity"] == []
    assert limited["reports"]["total"] == 6
    editor = _admin(client, "CONTENT_EDITOR", "dashboard-editor@example.com")
    assert (
        client.get("/api/v1/admin/dashboard", headers=_headers(editor["access_token"])).status_code
        == 403
    )
    assert client.get("/api/v1/admin/dashboard").status_code == 401


def test_demo_seed_preserves_changes_and_cannot_run_in_production(client: TestClient) -> None:
    _admin(client, "SUPER_ADMIN", "seed@example.com")
    settings = client.app.state.settings
    with client.app.state.session_factory() as db:
        seed_demo_data(db, settings, "seed@example.com", _dataset())
        row = db.get(GovernedContent, "demo.fyp.term-hypertension")
        row.lifecycle_state = "archived"
        db.commit()
        assert seed_demo_data(db, settings, "seed@example.com", _dataset()) == {
            "content": 0,
            "reports": 0,
            "imports": 0,
        }
        db.refresh(row)
        assert row.lifecycle_state == "archived"
        assert db.scalar(select(func.count()).select_from(ContentImportJob)) == 2
        assert (
            db.scalar(select(User).where(User.email == "demo.fyp.author@example.com")).is_active
            is False
        )
        settings.environment = "production"
        with pytest.raises(ValueError, match="restricted"):
            seed_demo_data(db, settings, "seed@example.com", _dataset())
        settings.environment = "testing"
        with pytest.raises(ValueError, match="administrator"):
            seed_demo_data(db, settings, "missing@example.com", _dataset())
