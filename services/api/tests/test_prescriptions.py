from datetime import UTC, datetime, timedelta

from fastapi.testclient import TestClient

from tests.conftest import auth_headers


def _field(*, confirmed: bool = False) -> dict[str, object]:
    return {
        "type": "medicationName",
        "original_value": "Amoxici1lin",
        "machine_normalized_value": "Amoxicillin",
        "current_value": "Amoxicillin",
        "source": "user",
        "confidence": "unknown",
        "ambiguous": False,
        "user_confirmed": confirmed,
        "changed_at": "2026-08-13T02:00:00Z",
        "possible_meanings": ["Amoxicillin"],
    }


def _payload(
    prescription_id: str = "11111111-1111-4111-8111-111111111111",
    *,
    confirmed: bool = False,
) -> dict[str, object]:
    return {
        "id": prescription_id,
        "source_type": "camera",
        "capture_date": "2026-08-13T02:00:00Z",
        "parser_version": "module3-rules-1.0.0",
        "ocr_provider": "google_mlkit_text_recognition",
        "ocr_provider_version": "0.16.0",
        "page_count": 1,
        "verification_state": ("readyForMedicationLookup" if confirmed else "userReviewRequired"),
        "user_confirmed_at": "2026-08-13T02:05:00Z" if confirmed else None,
        "updated_at": "2026-08-13T02:05:00Z",
        "items": [
            {
                "id": "22222222-2222-4222-8222-222222222222",
                "state": "readyForLookup" if confirmed else "needsReview",
                "page_number": 1,
                "position": 0,
                "fields": [_field(confirmed=confirmed)],
            }
        ],
    }


def _register(client: TestClient, email: str) -> dict[str, str]:
    response = client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": "SecurePassword!123",
            "display_name": "Synthetic Test",
        },
    )
    assert response.status_code == 201
    return response.json()


def test_create_list_read_update_delete_and_idempotency(
    client: TestClient, registered: dict[str, str]
) -> None:
    headers = auth_headers(registered["access_token"])
    payload = _payload()
    first = client.post("/api/v1/prescriptions", headers=headers, json=payload)
    second = client.post("/api/v1/prescriptions", headers=headers, json=payload)
    assert first.status_code == 201
    assert second.status_code == 201
    assert first.json()["id"] == second.json()["id"]
    assert "raw_ocr_text" not in first.json()
    assert "image" not in first.text.lower()

    listed = client.get("/api/v1/prescriptions", headers=headers)
    assert listed.status_code == 200
    assert listed.json()[0]["item_count"] == 1

    server_id = first.json()["id"]
    read = client.get(f"/api/v1/prescriptions/{server_id}", headers=headers)
    assert read.status_code == 200
    assert read.json()["revision"] == 1

    updated_at = datetime(2026, 8, 13, 2, 6, tzinfo=UTC).isoformat()
    patched = client.patch(
        f"/api/v1/prescriptions/{server_id}",
        headers=headers,
        json={
            "revision": 1,
            "verification_state": "userReviewRequired",
            "user_confirmed_at": None,
            "updated_at": updated_at,
            "items": payload["items"],
        },
    )
    assert patched.status_code == 200
    assert patched.json()["revision"] == 2

    deleted = client.delete(f"/api/v1/prescriptions/{server_id}", headers=headers)
    assert deleted.status_code == 204
    assert client.get(f"/api/v1/prescriptions/{server_id}", headers=headers).status_code == 404


def test_cross_user_access_is_hidden(client: TestClient, registered: dict[str, str]) -> None:
    first_headers = auth_headers(registered["access_token"])
    created = client.post("/api/v1/prescriptions", headers=first_headers, json=_payload())
    server_id = created.json()["id"]
    second = _register(client, "second-prescription-user@example.com")
    second_headers = auth_headers(second["access_token"])
    assert (
        client.get(f"/api/v1/prescriptions/{server_id}", headers=second_headers).status_code == 404
    )
    assert (
        client.patch(
            f"/api/v1/prescriptions/{server_id}",
            headers=second_headers,
            json={
                "revision": 1,
                "updated_at": "2026-08-13T03:00:00Z",
            },
        ).status_code
        == 404
    )
    assert (
        client.delete(f"/api/v1/prescriptions/{server_id}", headers=second_headers).status_code
        == 404
    )


def test_confirm_requires_ready_items(client: TestClient, registered: dict[str, str]) -> None:
    headers = auth_headers(registered["access_token"])
    created = client.post("/api/v1/prescriptions", headers=headers, json=_payload())
    response = client.post(f"/api/v1/prescriptions/{created.json()['id']}/confirm", headers=headers)
    assert response.status_code == 409

    confirmed_payload = _payload("33333333-3333-4333-8333-333333333333", confirmed=True)
    confirmed = client.post("/api/v1/prescriptions", headers=headers, json=confirmed_payload)
    response = client.post(
        f"/api/v1/prescriptions/{confirmed.json()['id']}/confirm", headers=headers
    )
    assert response.status_code == 200
    assert response.json()["verification_state"] == "readyForMedicationLookup"


def test_conflict_protects_newer_and_confirmed_values(
    client: TestClient, registered: dict[str, str]
) -> None:
    headers = auth_headers(registered["access_token"])
    payload = _payload(confirmed=True)
    created = client.post("/api/v1/prescriptions", headers=headers, json=payload)
    server_id = created.json()["id"]

    stale = client.patch(
        f"/api/v1/prescriptions/{server_id}",
        headers=headers,
        json={
            "revision": 99,
            "updated_at": "2026-08-13T03:00:00Z",
        },
    )
    assert stale.status_code == 409

    downgraded_items = payload["items"].copy()
    downgraded_items[0] = {**downgraded_items[0], "state": "needsReview"}
    downgraded = client.patch(
        f"/api/v1/prescriptions/{server_id}",
        headers=headers,
        json={
            "revision": 1,
            "updated_at": "2026-08-13T03:00:00Z",
            "items": downgraded_items,
        },
    )
    assert downgraded.status_code == 409


def test_items_reports_barcode_and_validation(
    client: TestClient, registered: dict[str, str]
) -> None:
    headers = auth_headers(registered["access_token"])
    created = client.post("/api/v1/prescriptions", headers=headers, json=_payload())
    server_id = created.json()["id"]
    item = {
        "id": "44444444-4444-4444-8444-444444444444",
        "state": "edited",
        "page_number": 1,
        "position": 1,
        "fields": [_field()],
    }
    added = client.post(f"/api/v1/prescriptions/{server_id}/items", headers=headers, json=item)
    assert added.status_code == 201
    patched = client.patch(
        f"/api/v1/prescriptions/{server_id}/items/{item['id']}",
        headers=headers,
        json={
            "state": "unresolved",
            "updated_at": (datetime.now(UTC) + timedelta(days=1)).isoformat(),
        },
    )
    assert patched.status_code == 200
    assert patched.json()["state"] == "unresolved"
    assert (
        client.delete(
            f"/api/v1/prescriptions/{server_id}/items/{item['id']}", headers=headers
        ).status_code
        == 204
    )
    report = client.post(
        f"/api/v1/prescriptions/{server_id}/reports",
        headers=headers,
        json={"reason": "ocrError", "note": "Synthetic test only"},
    )
    assert report.status_code == 201

    barcode = {
        "id": "55555555-5555-4555-8555-555555555555",
        "format": "ean13",
        "raw_value": "1234567890128",
        "source": "device_camera",
        "scanned_at": "2026-08-13T02:00:00Z",
        "user_confirmed": True,
    }
    first = client.post("/api/v1/prescriptions/barcode-scans", headers=headers, json=barcode)
    second = client.post("/api/v1/prescriptions/barcode-scans", headers=headers, json=barcode)
    assert first.status_code == second.status_code == 201
    assert first.json()["server_id"] == second.json()["server_id"]

    malformed = _payload("66666666-6666-4666-8666-666666666666")
    malformed["raw_ocr_text"] = "must not be accepted"
    response = client.post("/api/v1/prescriptions", headers=headers, json=malformed)
    assert response.status_code == 422
