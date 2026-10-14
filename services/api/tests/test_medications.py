from datetime import UTC, datetime

from fastapi.testclient import TestClient

from tests.conftest import auth_headers


def _confirmed_prescription(
    client: TestClient,
    token: str,
    *,
    prescription_id: str = "11111111-1111-4111-8111-111111111111",
    item_id: str = "item-1",
) -> None:
    now = datetime.now(UTC).isoformat()
    response = client.post(
        "/api/v1/prescriptions",
        headers=auth_headers(token),
        json={
            "id": prescription_id,
            "source_type": "userEntered",
            "capture_date": now,
            "parser_version": "test",
            "ocr_provider": None,
            "ocr_provider_version": None,
            "page_count": 0,
            "verification_state": "readyForMedicationLookup",
            "user_confirmed_at": now,
            "updated_at": now,
            "items": [
                {
                    "id": item_id,
                    "state": "readyForLookup",
                    "page_number": 0,
                    "position": 0,
                    "fields": [
                        {
                            "type": "medicationName",
                            "original_value": None,
                            "machine_normalized_value": None,
                            "current_value": "Amoxicillin",
                            "source": "user",
                            "confidence": "unknown",
                            "ambiguous": False,
                            "user_confirmed": True,
                            "changed_at": now,
                            "possible_meanings": [],
                        }
                    ],
                }
            ],
        },
    )
    assert response.status_code == 201


def _plan(updated_at: str, *, instruction: str = "Take one capsule") -> dict[str, object]:
    return {
        "id": "plan-1",
        "medication_id": "medicine-1",
        "prescription_item_id": "item-1",
        "source_type": "confirmedPrescription",
        "display_name": "Amoxicillin",
        "strength": "500 mg",
        "dosage_form": "capsule",
        "confirmed_dose_text": "1 capsule",
        "confirmed_frequency": "three times daily",
        "confirmed_duration": "7 days",
        "raw_prescription_instruction": "1 cap TID x 7d",
        "confirmed_instruction": instruction,
        "start_date": "2026-08-13",
        "end_date": "2026-08-20",
        "instructions": instruction,
        "timezone": "Asia/Karachi",
        "schedule": {
            "type": "threeTimesDaily",
            "reminder_times": [480, 840, 1200],
            "weekdays": [],
            "interval_hours": None,
            "interval_anchor": None,
            "as_needed": False,
        },
        "updated_at": updated_at,
    }


def test_plan_requires_verified_prescription_and_source_is_immutable(
    client: TestClient, registered: dict[str, str]
) -> None:
    token = registered["access_token"]
    now = datetime.now(UTC).isoformat()
    rejected = client.put(
        "/api/v1/medications/plans/plan-1",
        headers=auth_headers(token),
        json=_plan(now),
    )
    assert rejected.status_code == 409
    _confirmed_prescription(client, token)
    created = client.put(
        "/api/v1/medications/plans/plan-1",
        headers=auth_headers(token),
        json=_plan(now),
    )
    assert created.status_code == 200
    assert created.json()["revision"] == 1
    duplicate = client.put(
        "/api/v1/medications/plans/plan-1",
        headers=auth_headers(token),
        json=_plan(now),
    )
    assert duplicate.status_code == 200
    changed = _plan(
        datetime.now(UTC).replace(microsecond=999999).isoformat(), instruction="Different"
    )
    immutable = client.put(
        "/api/v1/medications/plans/plan-1",
        headers=auth_headers(token),
        json=changed,
    )
    assert immutable.status_code == 409


def test_dose_event_exactly_once_and_newer_revision_wins(
    client: TestClient, registered: dict[str, str]
) -> None:
    token = registered["access_token"]
    _confirmed_prescription(client, token)
    now = datetime.now(UTC).isoformat()
    assert (
        client.put(
            "/api/v1/medications/plans/plan-1",
            headers=auth_headers(token),
            json=_plan(now),
        ).status_code
        == 200
    )
    event = {
        "id": "event-1",
        "medication_plan_id": "plan-1",
        "logical_dose_id": "plan-1:2026-08-13T08:00:00Z",
        "scheduled_at": "2026-08-13T08:00:00Z",
        "action": "notRecorded",
        "recorded_at": "2026-08-13T08:01:00Z",
        "source": "app",
        "note": None,
        "supersedes_event_id": None,
        "revision": 1,
    }
    first = client.put(
        "/api/v1/medications/dose-events/event-1",
        headers=auth_headers(token),
        json=event,
    )
    assert first.status_code == 200
    duplicate = client.put(
        "/api/v1/medications/dose-events/event-1",
        headers=auth_headers(token),
        json=event,
    )
    assert duplicate.status_code == 200
    corrected = event | {
        "id": "event-2",
        "action": "taken",
        "recorded_at": "2026-08-13T08:02:00Z",
        "supersedes_event_id": "event-1",
        "revision": 2,
    }
    latest = client.put(
        "/api/v1/medications/dose-events/event-2",
        headers=auth_headers(token),
        json=corrected,
    )
    assert latest.status_code == 200
    assert latest.json()["accepted_as_latest"] is True


def test_as_needed_rejects_fixed_times(client: TestClient, registered: dict[str, str]) -> None:
    token = registered["access_token"]
    payload = _plan(datetime.now(UTC).isoformat())
    payload["source_type"] = "manualEntry"
    payload["prescription_item_id"] = None
    payload["schedule"] = {
        "type": "asNeeded",
        "reminder_times": [480],
        "weekdays": [],
        "interval_hours": None,
        "interval_anchor": None,
        "as_needed": True,
    }
    response = client.put(
        "/api/v1/medications/plans/plan-1",
        headers=auth_headers(token),
        json=payload,
    )
    assert response.status_code == 422


def test_verified_item_lookup_checks_all_confirmed_prescriptions(
    client: TestClient, registered: dict[str, str]
) -> None:
    token = registered["access_token"]
    _confirmed_prescription(
        client,
        token,
        prescription_id="22222222-2222-4222-8222-222222222222",
        item_id="other-item",
    )
    _confirmed_prescription(client, token)
    response = client.put(
        "/api/v1/medications/plans/plan-1",
        headers=auth_headers(token),
        json=_plan(datetime.now(UTC).isoformat()),
    )
    assert response.status_code == 200


def test_plan_pause_round_trips_as_an_explicit_state(
    client: TestClient, registered: dict[str, str]
) -> None:
    token = registered["access_token"]
    _confirmed_prescription(client, token)
    first_time = datetime.now(UTC)
    assert (
        client.put(
            "/api/v1/medications/plans/plan-1",
            headers=auth_headers(token),
            json=_plan(first_time.isoformat()),
        ).status_code
        == 200
    )
    paused = _plan(first_time.replace(microsecond=999999).isoformat())
    paused["active"] = False
    paused["medication_status"] = "pausedByUser"
    response = client.put(
        "/api/v1/medications/plans/plan-1",
        headers=auth_headers(token),
        json=paused,
    )
    assert response.status_code == 200
    assert response.json()["active"] is False
    assert response.json()["medication_status"] == "pausedByUser"
