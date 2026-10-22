import hashlib
import json
from uuid import UUID

import httpx
import pytest
from pydantic import SecretStr

from app.core.time import utc_now
from app.models import FeatureFlag, MedicalFact, MedicationIdentity, ProviderHealthEvent
from app.services.medicine_batch_overview import BatchOverviewRequest, MedicineBatchOverviewService
from app.services.medicine_overview import MedicineOverview, MedicineOverviewService
from tests.conftest import auth_headers


@pytest.fixture
def batch_setup(client, registered, monkeypatch):
    config = client.app.state.settings
    config.gemini_api_key = SecretStr("synthetic-gemini")
    known = {}
    with client.app.state.session_factory() as db:
        db.get(FeatureFlag, "ai_assistant").enabled = True
        for name in ["Fixture Alpha", "Fixture Beta"]:
            medicine = MedicationIdentity(
                canonical_display_name=name,
                normalized_name=name.casefold(),
                generic_name=name,
                brand_names=[],
                verification_state="external_identity_verified",
            )
            medicine.facts = [
                MedicalFact(
                    fact_type="patient_information",
                    content=f"{name}: The supplied source contains general information.",
                    provider="dailymed",
                    source_id=name,
                    source_title="Synthetic engineering source",
                    source_section="Patient information",
                    citation_reference="https://example.com/engineering-fixture",
                    jurisdiction="US",
                    language="en",
                    content_version="fixture",
                    content_hash=hashlib.sha256(name.encode()).hexdigest(),
                    retrieved_at=utc_now(),
                )
            ]
            db.add(medicine)
            db.flush()
            known[name] = (medicine.id, str(medicine.facts[0].id))
        db.commit()

    def prepare(self, request):
        if request.name not in known:
            return MedicineOverview(
                status="unavailable", message=f"Check the spelling of {request.name}."
            )
        return MedicineOverview(
            status="available",
            medication_id=known[request.name][0],
            reference_name=request.name,
            message="General reference.",
        )

    monkeypatch.setattr(MedicineOverviewService, "prepare", prepare)
    return config, known


def payload(names=None):
    return {
        "language": "en",
        "medicines": [
            {"item_id": str(i), "name": name, "user_confirmed": True}
            for i, name in enumerate(
                names or ["Fixture Alpha", "Fixture Beta", "Unreadable fixture"]
            )
        ],
    }


def generated(known):
    return {
        "medicines": [
            {
                "item_id": str(i),
                "answer": "The supplied source contains general information.",
                "source_ids": [known[name][1]],
                "mentioned_medications": [],
            }
            for i, name in enumerate(["Fixture Alpha", "Fixture Beta"])
        ]
        + [{"item_id": "2", "answer": None, "source_ids": [], "mentioned_medications": []}]
    }


def gemini(body):
    return httpx.Response(
        200,
        json={
            "candidates": [
                {"finishReason": "STOP", "content": {"parts": [{"text": json.dumps(body)}]}}
            ]
        },
    )


def run(client, registered, config, response):
    with (
        httpx.Client(transport=httpx.MockTransport(response)) as transport,
        client.app.state.session_factory() as db,
    ):
        return MedicineBatchOverviewService(db, config, client=transport).overview(
            UUID(registered["user_id"]), BatchOverviewRequest.model_validate(payload())
        )


def test_complete_list_is_sent_in_one_ai_request_and_every_item_is_returned(
    client, registered, batch_setup
):
    config, known = batch_setup
    calls = []

    def respond(request):
        calls.append(request)
        text = json.loads(request.content)["contents"][0]["parts"][0]["text"]
        data = json.loads(text)
        assert [r["reviewed_name"] for r in data["medicines"]] == [
            "Fixture Alpha",
            "Fixture Beta",
            "Unreadable fixture",
        ]
        return gemini(generated(known))

    result = run(client, registered, config, respond)
    assert len(calls) == 1
    assert [r.item_id for r in result.medicines] == ["0", "1", "2"]
    assert all(r.overview.explanation.ai_provider_used for r in result.medicines[:2])
    assert result.medicines[2].overview.explanation is None
    assert "Unreadable fixture" in result.medicines[2].overview.message


@pytest.mark.parametrize(
    "problem", ["missing", "duplicate", "cross_wired", "malformed", "invented_number"]
)
def test_bad_model_item_does_not_drop_the_list_or_other_explanations(
    client, registered, batch_setup, problem
):
    config, known = batch_setup
    body = generated(known)
    if problem == "missing":
        body["medicines"].pop(0)
    elif problem == "duplicate":
        body["medicines"].append(dict(body["medicines"][0]))
    elif problem == "cross_wired":
        body["medicines"][0]["source_ids"] = [known["Fixture Beta"][1]]
    elif problem == "malformed":
        body["medicines"][0]["answer"] = {"unexpected": "object"}
    else:
        body["medicines"][0]["answer"] = "This medicine contains 999 mg."
    result = run(client, registered, config, lambda _: gemini(body))
    assert len(result.medicines) == 3
    alpha, beta, unknown = [r.overview for r in result.medicines]
    assert alpha.explanation.ai_provider_used is False
    assert alpha.explanation.source_references[0].id == known["Fixture Alpha"][1]
    assert beta.explanation.ai_provider_used is True
    assert unknown.explanation is None
    assert "999" not in alpha.explanation.answer
    with client.app.state.session_factory() as db:
        event = db.query(ProviderHealthEvent).filter_by(operation="batch_explanation").one()
        assert event.success is False and event.safe_error_code == "batch_partial_or_unverified"


def test_cloud_quota_failover_sends_whole_batch_to_groq_once(client, registered, batch_setup):
    config, known = batch_setup
    config.groq_api_key = SecretStr("synthetic-groq")
    calls = []

    def respond(request):
        calls.append(request.url.host)
        if request.url.host == "generativelanguage.googleapis.com":
            return httpx.Response(429)
        body = json.loads(request.content)
        data = json.loads(body["messages"][1]["content"][0]["text"])
        assert len(data["medicines"]) == 3
        return httpx.Response(
            200,
            json={
                "choices": [
                    {"finish_reason": "stop", "message": {"content": json.dumps(generated(known))}}
                ]
            },
        )

    result = run(client, registered, config, respond)
    assert calls == ["generativelanguage.googleapis.com", "api.groq.com"]
    assert result.medicines[0].overview.explanation.generation_provider == "groq"


def test_both_cloud_quotas_send_one_batch_to_small_ollama(client, registered, batch_setup):
    config, known = batch_setup
    config.groq_api_key = SecretStr("synthetic-groq")
    calls = []

    def respond(request):
        calls.append(request.url.host)
        if request.url.host in {"generativelanguage.googleapis.com", "api.groq.com"}:
            return httpx.Response(429)
        body = json.loads(request.content)
        assert body["model"] == "qwen3:1.7b" and body["think"] is False
        assert len(json.loads(body["messages"][1]["content"])["medicines"]) == 3
        return httpx.Response(200, json={"message": {"content": json.dumps(generated(known))}})

    result = run(client, registered, config, respond)
    assert len(calls) == 3
    assert result.medicines[0].overview.explanation.generation_provider == "ollama"


def test_unavailable_ai_preserves_official_information_for_all_verified_items(
    client, registered, batch_setup
):
    config, _ = batch_setup
    result = run(client, registered, config, lambda _: httpx.Response(401))
    assert all(r.overview.explanation.answer_type == "source_extract" for r in result.medicines[:2])
    assert len(result.medicines) == 3


def test_batch_endpoint_auth_confirmation_unique_ids_and_no_store(
    client, registered, batch_setup, monkeypatch
):
    path = "/api/v1/prescription-ocr/medicine-overviews"
    assert client.post(path, json=payload()).status_code == 401
    headers = auth_headers(registered["access_token"])
    invalid = payload()
    invalid["medicines"][0]["user_confirmed"] = False
    assert client.post(path, headers=headers, json=invalid).status_code == 422
    invalid = payload()
    invalid["medicines"][1]["item_id"] = "0"
    assert client.post(path, headers=headers, json=invalid).status_code == 422
    with client.app.state.session_factory() as db:
        db.get(FeatureFlag, "ai_assistant").enabled = False
        db.commit()
    response = client.post(path, headers=headers, json=payload())
    assert response.status_code == 200
    assert response.headers["cache-control"] == "no-store"
    assert len(response.json()["medicines"]) == 3


def test_short_source_keys_expand_to_real_citations_without_cross_wiring(
    client, registered, batch_setup
):
    config, known = batch_setup

    def respond(request):
        document = json.loads(json.loads(request.content)["contents"][0]["parts"][0]["text"])
        output = generated(known)
        for i in range(2):
            sources = document["medicines"][i]["sources"]
            assert sources[0]["source_id"] == f"s{i}_0"
            output["medicines"][i]["source_ids"] = [sources[0]["source_id"]]
        return gemini(output)

    result = run(client, registered, config, respond)
    for row in result.medicines[:2]:
        assert row.overview.explanation.ai_provider_used
        assert row.overview.explanation.source_references[0].id == known[row.name][1]


def test_newer_source_versions_do_not_crowd_out_other_ingredient_information():
    from datetime import UTC, datetime, timedelta

    from app.services.medicine_batch_overview import _latest_facts

    now = datetime.now(UTC)
    old = MedicalFact(
        provider="medlineplus",
        source_id="ingredient-a",
        fact_type="patient_information",
        language="en",
        retrieved_at=now - timedelta(days=1),
    )
    recent = MedicalFact(
        provider="medlineplus",
        source_id="ingredient-a",
        fact_type="patient_information",
        language="en",
        retrieved_at=now,
    )
    other = MedicalFact(
        provider="medlineplus",
        source_id="ingredient-b",
        fact_type="patient_information",
        language="en",
        retrieved_at=now,
    )
    assert _latest_facts([old, recent, other]) == [recent, other]


@pytest.mark.parametrize("status", [404, 501])
def test_unavailable_google_without_groq_keeps_whole_batch_local(
    client, registered, batch_setup, status
):
    config, known = batch_setup
    config.groq_api_key = None
    calls = []

    def respond(request):
        calls.append(request.url.host)
        if request.url.host == "generativelanguage.googleapis.com":
            return httpx.Response(status)
        body = json.loads(request.content)
        assert body["model"] == "qwen3:1.7b"
        assert len(json.loads(body["messages"][1]["content"])["medicines"]) == 3
        return httpx.Response(200, json={"message": {"content": json.dumps(generated(known))}})

    result = run(client, registered, config, respond)
    assert len(calls) == 3
    assert all(
        item.overview.explanation.generation_provider == "ollama"
        for item in result.medicines[:2]
    )
    assert result.medicines[2].overview.explanation is None
