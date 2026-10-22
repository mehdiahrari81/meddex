"""Fast scanning keeps the same source validation and uncertainty guarantees."""

import io
import json
from uuid import UUID

import httpx
from PIL import Image
from pydantic import SecretStr

from app.core.config import Settings
from app.providers.medication import ProviderCandidate, RxNormReferenceProvider
from app.services.gemini_handwriting import transcribe_handwriting
from app.services.medication_intelligence import MedicationIntelligenceService
from app.services.medicine_overview import MedicineOverviewRequest, MedicineOverviewService
from tests.test_intelligence import _grounded_medication


def test_fast_reader_and_bounded_detail_review_do_not_confirm_unclear_doses():
    calls = []

    def respond(request):
        calls.append(request)
        if len(calls) == 1:
            assert "/gemini-3.5-flash-lite:" in request.url.path
            assert request.extensions["timeout"]["read"] <= 18
            payload = {
                "lines": [
                    {"text": "Metformin 5?0 mg", "uncertain": True, "uncertain_spans": ["5?0 mg"]}
                ]
            }
        else:
            assert "/gemini-3.1-flash-lite:" in request.url.path
            assert 7.9 <= request.extensions["timeout"]["read"] <= 8
            raise httpx.ReadTimeout("Synthetic slow detailed reader", request=request)
        return httpx.Response(
            200,
            json={
                "candidates": [
                    {"finishReason": "STOP", "content": {"parts": [{"text": json.dumps(payload)}]}}
                ]
            },
        )

    buffer = io.BytesIO()
    Image.new("RGB", (300, 100), "white").save(buffer, format="JPEG")
    with httpx.Client(transport=httpx.MockTransport(respond)) as client:
        result = transcribe_handwriting(
            Settings(gemini_api_key=SecretStr("qa")), client, buffer.getvalue()
        )
    assert len(calls) == 2
    assert result["model"] == "gemini-3.5-flash-lite"
    assert result["requires_review"] is True
    assert result["uncertain_line_numbers"] == [1]
    assert "[uncertain: 5?0 mg]" in result["text"]
    assert result["detail_review_completed"] is False


def test_fully_specified_local_reference_does_not_wait_for_remote_identity_search(
    client, registered, monkeypatch
):
    reference = _grounded_medication(client)
    local = ProviderCandidate(
        external_id="fixture",
        canonical_name="Source medicine",
        generic_name="source ingredient",
        provider="rxnorm",
        provider_version="synthetic-engineering-fixture",
        strength="10 mg",
        dosage_form="tablet",
    )
    monkeypatch.setattr(RxNormReferenceProvider, "search", lambda *a: [local])

    def remote(*args):
        raise AssertionError("Exact installed reference must not make a remote identity request")

    monkeypatch.setattr(MedicationIntelligenceService, "_run_search", remote)
    monkeypatch.setattr(MedicationIntelligenceService, "reference_identity", lambda *a: reference)
    monkeypatch.setattr(MedicationIntelligenceService, "refresh_facts", lambda *a: "current")
    with client.app.state.session_factory() as db:
        result = MedicineOverviewService(db, client.app.state.settings).overview(
            UUID(registered["user_id"]),
            MedicineOverviewRequest(name="Source medicine", strength="10 mg", dosage_form="tablet"),
        )
    assert result.status == "available"
    assert result.prescription_confirmed is False
    assert result.explanation.source_references
