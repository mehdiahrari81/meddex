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


def test_saved_medicine_without_invented_instructions_has_no_active_reminders(client, registered):
    token = registered["access_token"]
    _confirmed_prescription(client, token)
    payload = _plan(datetime.now(UTC).isoformat())
    payload.update(active=False, confirmed_dose_text="", confirmed_frequency="")
    payload["schedule"] = {"type": "custom", "reminder_times": []}
    result = client.put(
        "/api/v1/medications/plans/plan-1", headers=auth_headers(token), json=payload
    )
    assert result.status_code == 200
    assert result.json()["active"] is False
    assert result.json()["confirmed_dose_text"] == ""
    payload["active"] = True
    assert (
        client.put(
            "/api/v1/medications/plans/plan-1", headers=auth_headers(token), json=payload
        ).status_code
        == 422
    )


def test_deleting_source_scan_preserves_owned_saved_medicine_updates(client, registered):
    from datetime import timedelta

    token = registered["access_token"]
    _confirmed_prescription(client, token)
    now = datetime.now(UTC)
    payload = _plan(now.isoformat())
    assert (
        client.put(
            "/api/v1/medications/plans/plan-1", headers=auth_headers(token), json=payload
        ).status_code
        == 200
    )
    assert (
        client.delete(
            "/api/v1/prescriptions/11111111-1111-4111-8111-111111111111",
            headers=auth_headers(token),
        ).status_code
        == 204
    )
    payload.update(
        prescription_item_id=None, active=False, updated_at=(now + timedelta(seconds=1)).isoformat()
    )
    result = client.put(
        "/api/v1/medications/plans/plan-1", headers=auth_headers(token), json=payload
    )
    assert result.status_code == 200
    assert result.json()["confirmed_instruction"] == payload["confirmed_instruction"]
    # A fresh plan cannot use a deleted/unconfirmed source, even with the same names.
    payload.update(id="new-plan", medication_id="new-medication")
    assert (
        client.put(
            "/api/v1/medications/plans/new-plan", headers=auth_headers(token), json=payload
        ).status_code
        == 409
    )


def test_delete_saved_medication_removes_related_records_and_rejects_replay(
    client: TestClient, registered: dict[str, str]
) -> None:
    from sqlalchemy import func, select

    from app.models import (
        DoseEvent,
        MedicationNote,
        MedicationPlan,
        MedicationPlanHistory,
        MedicationPlanSource,
        MedicationSchedule,
        RefillReminder,
        ReminderTime,
        UserMedication,
    )

    token = registered["access_token"]
    headers = auth_headers(token)
    _confirmed_prescription(client, token)
    payload = _plan(datetime.now(UTC).isoformat())
    assert (
        client.put("/api/v1/medications/plans/plan-1", headers=headers, json=payload).status_code
        == 200
    )
    other = dict(
        payload,
        id="other-plan",
        medication_id="other-medicine",
        source_type="manualEntry",
        prescription_item_id=None,
    )
    assert (
        client.put("/api/v1/medications/plans/other-plan", headers=headers, json=other).status_code
        == 200
    )
    event = {
        "id": "deleted-event",
        "medication_plan_id": "plan-1",
        "logical_dose_id": "deleted-dose",
        "scheduled_at": "2026-08-13T08:00:00Z",
        "action": "taken",
        "recorded_at": "2026-08-13T08:01:00Z",
        "source": "app",
        "note": "Private fixture note",
        "supersedes_event_id": None,
        "revision": 1,
    }
    assert (
        client.put(
            "/api/v1/medications/dose-events/deleted-event", headers=headers, json=event
        ).status_code
        == 200
    )
    with client.app.state.session_factory() as session:
        plan = session.scalar(select(MedicationPlan).where(MedicationPlan.client_id == "plan-1"))
        assert plan is not None
        plan_pk, medication_pk = plan.id, plan.medication_id
        schedule_ids = list(
            session.scalars(
                select(MedicationSchedule.id).where(MedicationSchedule.plan_id == plan.id)
            )
        )
        session.add(
            MedicationNote(
                user_id=plan.user_id, medication_id=medication_pk, note="Private fixture note"
            )
        )
        session.add(RefillReminder(user_id=plan.user_id, plan_id=plan.id))
        session.add(MedicationPlanHistory(user_id=plan.user_id, plan_id=plan.id, action="fixture"))
        session.commit()
    endpoint = "/api/v1/medications/saved/medicine-1"
    assert client.delete(endpoint, headers=headers).status_code == 204
    assert client.delete(endpoint, headers=headers).status_code == 204
    remaining = client.get("/api/v1/medications/plans", headers=headers).json()
    assert [plan["id"] for plan in remaining] == ["other-plan"]
    assert (
        client.put("/api/v1/medications/plans/plan-1", headers=headers, json=payload).status_code
        == 410
    )
    assert (
        client.put(
            "/api/v1/medications/dose-events/deleted-event", headers=headers, json=event
        ).status_code
        == 404
    )
    assert (
        client.get(
            "/api/v1/prescriptions/11111111-1111-4111-8111-111111111111", headers=headers
        ).status_code
        == 200
    )
    with client.app.state.session_factory() as session:
        for model in (
            DoseEvent,
            RefillReminder,
            MedicationPlanHistory,
            MedicationPlanSource,
            MedicationSchedule,
        ):
            assert (
                session.scalar(
                    select(func.count()).select_from(model).where(model.plan_id == plan_pk)
                )
                == 0
            )
        assert (
            session.scalar(
                select(func.count())
                .select_from(ReminderTime)
                .where(ReminderTime.schedule_id.in_(schedule_ids))
            )
            == 0
        )
        assert (
            session.scalar(
                select(func.count())
                .select_from(MedicationNote)
                .where(MedicationNote.medication_id == medication_pk)
            )
            == 0
        )
        erased = session.get(UserMedication, medication_pk)
        assert erased is not None and erased.deleted_at is not None
        assert (
            erased.display_name == ""
            and erased.strength is None
            and erased.prescription_item_client_id is None
        )


def test_delete_saved_medication_is_owner_scoped_and_offline_delete_blocks_late_upload(
    client: TestClient, registered: dict[str, str]
) -> None:
    owner_headers = auth_headers(registered["access_token"])
    payload = _plan(datetime.now(UTC).isoformat())
    payload.update(source_type="manualEntry", prescription_item_id=None)
    assert (
        client.put(
            "/api/v1/medications/plans/plan-1", headers=owner_headers, json=payload
        ).status_code
        == 200
    )
    second = client.post(
        "/api/v1/auth/register",
        json={
            "email": "second-delete@example.com",
            "password": "SecurePassword!123",
            "display_name": "Second fixture",
        },
    ).json()
    second_headers = auth_headers(second["access_token"])
    assert (
        client.delete("/api/v1/medications/saved/medicine-1", headers=second_headers).status_code
        == 204
    )
    assert len(client.get("/api/v1/medications/plans", headers=owner_headers).json()) == 1
    assert (
        client.put(
            "/api/v1/medications/plans/plan-1", headers=second_headers, json=payload
        ).status_code
        == 410
    )
    assert client.get("/api/v1/medications/plans", headers=second_headers).json() == []
