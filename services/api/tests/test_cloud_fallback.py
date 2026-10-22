import base64
import io
import json

import httpx
import pytest
from PIL import Image
from pydantic import SecretStr

from app.core.config import Settings
from app.providers.ai import GeminiOllamaProvider, OllamaProvider, ProviderCooldown, shared_cooldown
from app.providers.cloud_fallback import CloudProvider, CloudProvidersUnavailable
from app.services.gemini_handwriting import transcribe_handwriting
from app.services.prescription_structuring import (
    PrescriptionStructuringService,
    StructurePrescriptionRequest,
)

SCHEMA = {
    "type": "object",
    "properties": {"answer": {"type": "string"}},
    "required": ["answer"],
    "additionalProperties": False,
}
ANSWER = {
    "answer": "The reference describes this medicine.",
    "mentioned_medications": [],
    "source_ids": ["reference"],
}


def settings(**kwargs):
    return Settings(
        _env_file=None,
        gemini_api_key=SecretStr("synthetic-gemini"),
        groq_api_key=SecretStr("synthetic-groq"),
        **kwargs,
    )


def cloud(client, configured=None):
    configured = configured or settings()
    return CloudProvider(
        settings=configured, client=client, model=configured.gemini_model, timeout_seconds=30
    )


def gemini_json(value):
    return httpx.Response(
        200,
        json={
            "candidates": [
                {"finishReason": "STOP", "content": {"parts": [{"text": json.dumps(value)}]}}
            ]
        },
    )


def groq_json(value):
    return httpx.Response(
        200,
        json={"choices": [{"finish_reason": "stop", "message": {"content": json.dumps(value)}}]},
    )


def generate(provider, **kwargs):
    return provider.generate_json_with_availability_fallback(
        fallback_model=provider.gemini_model,
        system_prompt="Return source-supported JSON.",
        text="Synthetic fixture",
        schema=SCHEMA,
        **kwargs,
    )


def test_gemini_success_never_calls_groq():
    calls = []

    def respond(request):
        calls.append(request.url.host)
        return gemini_json({"answer": "Gemini"})

    with httpx.Client(transport=httpx.MockTransport(respond)) as client:
        provider = cloud(client)
        assert json.loads(generate(provider))["answer"] == "Gemini"
        assert provider.used_provider == "gemini"
    assert calls == ["generativelanguage.googleapis.com"]


@pytest.mark.parametrize("status", [402, 429, 503])
def test_groq_fallback_backoff_across_requests(status):
    calls = []

    def respond(request):
        calls.append(request.url.host)
        if request.url.host == "generativelanguage.googleapis.com":
            return httpx.Response(status, headers={"Retry-After": "60"})
        assert request.headers["authorization"] == "Bearer synthetic-groq"
        assert "synthetic-groq" not in str(request.url)
        payload = json.loads(request.content)
        assert payload["response_format"]["json_schema"]["strict"] is True
        assert payload["reasoning_effort"] == "low"
        assert request.extensions["timeout"]["read"] <= 30
        return groq_json({"answer": "Groq"})

    with httpx.Client(transport=httpx.MockTransport(respond)) as client:
        for _ in range(2):
            provider = cloud(client)
            assert json.loads(generate(provider))["answer"] == "Groq"
            assert provider.used_provider == "groq"
    assert calls == ["generativelanguage.googleapis.com", "api.groq.com", "api.groq.com"]


def test_both_quotas_cool_down_without_repeating_requests():
    calls = []

    def respond(request):
        calls.append(request.url.host)
        return httpx.Response(429, headers={"Retry-After": "120"})

    with httpx.Client(transport=httpx.MockTransport(respond)) as client:
        for _ in range(2):
            with pytest.raises(CloudProvidersUnavailable) as error:
                generate(cloud(client))
            assert error.value.code == "cloud_limit_reached"
    assert calls == ["generativelanguage.googleapis.com", "api.groq.com"]


def test_primary_recovers_after_cooldown():
    clock = [10.0]
    config = settings()
    state = shared_cooldown(
        CloudProvider._fingerprint("synthetic-gemini"), "cloud:*"
    )
    state.clock = lambda: clock[0]
    calls = []

    def respond(request):
        calls.append(request.url.host)
        if request.url.host == "generativelanguage.googleapis.com":
            return (
                httpx.Response(429, headers={"Retry-After": "60"})
                if clock[0] == 10
                else gemini_json({"answer": "recovered"})
            )
        return groq_json({"answer": "fallback"})

    with httpx.Client(transport=httpx.MockTransport(respond)) as client:
        generate(cloud(client, config))
        clock[0] = 71
        provider = cloud(client, config)
        assert json.loads(generate(provider))["answer"] == "recovered"
        assert provider.used_provider == "gemini"
    assert calls.count("generativelanguage.googleapis.com") == 2


@pytest.mark.parametrize("status", [400, 401, 403])
def test_bad_credentials_or_permissions_are_not_quota_failover(status):
    calls = []

    def respond(request):
        calls.append(request.url.host)
        return httpx.Response(status)

    with (
        httpx.Client(transport=httpx.MockTransport(respond)) as client,
        pytest.raises(httpx.HTTPStatusError),
    ):
        generate(cloud(client))
    assert calls == ["generativelanguage.googleapis.com"]


def test_image_failover_preserves_full_page_and_limits_three_images():
    def respond(request):
        if request.url.host == "generativelanguage.googleapis.com":
            return httpx.Response(429)
        content = json.loads(request.content)["messages"][1]["content"]
        images = [part["image_url"]["url"] for part in content if part["type"] == "image_url"]
        assert len(images) == 3
        assert base64.b64decode(images[0].split(",")[1]) == b"whole-page"
        return groq_json({"answer": "image"})

    with httpx.Client(transport=httpx.MockTransport(respond)) as client:
        generate(
            cloud(client, settings(groq_vision_max_images=3)),
            image_bytes=b"whole-page",
            additional_images=[b"crop"] * 6,
        )


def test_both_cloud_quotas_use_small_ollama_for_text():
    calls = []

    def respond(request):
        calls.append(request.url.host)
        if request.url.host != "ollama.test":
            return httpx.Response(429)
        assert json.loads(request.content)["model"] == "qwen3:1.7b"
        return httpx.Response(200, json={"message": {"content": json.dumps(ANSWER)}})

    with httpx.Client(transport=httpx.MockTransport(respond)) as client:
        provider = GeminiOllamaProvider(
            primary=cloud(client),
            fallback=OllamaProvider(
                client=client, base_url="http://ollama.test", model="qwen3:1.7b"
            ),
            cooldown=ProviderCooldown(),
        )
        result = provider.explain(
            system_prompt="Use sources", context="SOURCE_ID=reference; source", question="Explain"
        )
        assert result.provider == "ollama"
        assert result.fallback_reason == "cloud_quota_exhausted"
    assert calls == ["generativelanguage.googleapis.com", "api.groq.com", "ollama.test"]


def test_groq_extraction_retains_evidence_validation():
    medicine = {
        "name": "Metformin",
        "page_number": 1,
        "line_numbers": [1],
        "strength": "500 mg",
        "dosage_form": "tablets",
        "dose": None,
        "route": None,
        "frequency": None,
        "duration": None,
        "instructions": None,
        "uncertain_fields": [],
    }

    def respond(request):
        if request.url.host == "generativelanguage.googleapis.com":
            return httpx.Response(429)
        return groq_json({"medicines": [medicine]})

    request = StructurePrescriptionRequest.model_validate(
        {"cloud_consent": True, "pages": [{"page_number": 1, "text": "Metformin 500 mg tablets"}]}
    )
    with httpx.Client(transport=httpx.MockTransport(respond)) as client:
        service = PrescriptionStructuringService(settings(), client)
        result = service.structure(request)
        assert result.provider == "groq"
        assert result.medicines[0].requires_review is True
        assert result.medicines[0].dose is None
        medicine["name"] = "Lipitor"
        with pytest.raises(ValueError, match="invalid_medicine_evidence"):
            service.structure(request)


def test_groq_image_transcription_retains_uncertainty():
    image = io.BytesIO()
    Image.new("RGB", (800, 600), "white").save(image, format="JPEG")

    def respond(request):
        if request.url.host == "generativelanguage.googleapis.com":
            return httpx.Response(429)
        return groq_json(
            {
                "lines": [
                    {"text": "Metformin 500? mg", "uncertain": True, "uncertain_spans": ["500?"]}
                ]
            }
        )

    with httpx.Client(transport=httpx.MockTransport(respond)) as client:
        result = transcribe_handwriting(
            settings(gemini_handwriting_recheck=False), client, image.getvalue()
        )
    assert result["provider"] == "groq"
    assert result["requires_review"] is True
    assert "[uncertain: 500?]" in result["text"]


def test_truncated_groq_output_is_rejected():
    def respond(request):
        if request.url.host == "generativelanguage.googleapis.com":
            return httpx.Response(429)
        return httpx.Response(
            200, json={"choices": [{"finish_reason": "length", "message": {"content": "{}"}}]}
        )

    with (
        httpx.Client(transport=httpx.MockTransport(respond)) as client,
        pytest.raises(ValueError, match="groq_blocked_or_incomplete"),
    ):
        generate(cloud(client))


def test_optional_groq_detail_quota_keeps_the_initial_transcription():
    image = io.BytesIO()
    Image.new("RGB", (800, 600), "white").save(image, format="JPEG")
    groq_calls = 0

    def respond(request):
        nonlocal groq_calls
        if request.url.host == "generativelanguage.googleapis.com":
            return httpx.Response(429)
        groq_calls += 1
        if groq_calls > 1:
            return httpx.Response(429)
        return groq_json(
            {
                "lines": [
                    {"text": "Metformin 500? mg", "uncertain": True, "uncertain_spans": ["500?"]}
                ]
            }
        )

    with httpx.Client(transport=httpx.MockTransport(respond)) as client:
        result = transcribe_handwriting(settings(), client, image.getvalue())
    assert result["detail_review_attempted"] is True
    assert result["detail_review_completed"] is False
    assert "[uncertain: 500?]" in result["text"]
    assert result["requires_review"] is True


def test_missing_gemini_key_uses_groq_without_sending_an_empty_key():
    config = settings()
    config.gemini_api_key = None

    def respond(request):
        assert request.url.host == "api.groq.com"
        return groq_json(ANSWER)

    with httpx.Client(transport=httpx.MockTransport(respond)) as client:
        result = cloud(client, config).explain(
            system_prompt="Use sources", context="SOURCE_ID=reference; source", question="Explain"
        )
    assert result.provider == "groq"
    assert result.fallback_reason == "gemini_not_configured"


def test_groq_explanation_passes_real_rag_grounding(client, registered):
    from uuid import UUID

    from app.models import FeatureFlag, MedicationIdentity, ProviderHealthEvent
    from app.schemas.intelligence import AiQuestionRequest
    from app.services.medical_rag import MedicalRagService
    from tests.test_intelligence import _grounded_medication

    medication = _grounded_medication(client)
    config = client.app.state.settings
    config.groq_api_key = SecretStr("synthetic-groq")
    config.gemini_api_key = SecretStr("synthetic-gemini")
    with client.app.state.session_factory() as db:
        db.get(FeatureFlag, "ai_assistant").enabled = True
        db.commit()
        fact = db.get(MedicationIdentity, medication.id).facts[0]

        def respond(request):
            if request.url.host == "generativelanguage.googleapis.com":
                return httpx.Response(429)
            return groq_json(
                {
                    "answer": "The source says to read the official patient information.",
                    "mentioned_medications": [],
                    "source_ids": [str(fact.id)],
                }
            )

        with httpx.Client(transport=httpx.MockTransport(respond)) as transport:
            result = MedicalRagService(db, config, client=transport).answer(
                user_id=UUID(registered["user_id"]),
                request=AiQuestionRequest(
                    question="Explain the warnings", medication_id=medication.id
                ),
            )
        assert result.ai_provider_used is True
        assert result.generation_provider == "groq"
        assert result.source_references
        assert not any("Groq generated" in text for text in result.limitations)
        assert db.query(ProviderHealthEvent).one().provider == "ai_groq"


def test_successful_groq_detail_reading_reports_actual_provenance():
    image = io.BytesIO()
    Image.new("RGB", (800, 600), "white").save(image, format="JPEG")
    groq_calls = 0

    def respond(request):
        nonlocal groq_calls
        if request.url.host == "generativelanguage.googleapis.com":
            return httpx.Response(429)
        groq_calls += 1
        line = {"text": "Metformin 500? mg", "uncertain": True, "uncertain_spans": ["500?"]}
        if groq_calls == 2:
            line["line_index"] = 0
        return groq_json({"lines": [line]})

    config = settings()
    with httpx.Client(transport=httpx.MockTransport(respond)) as client:
        result = transcribe_handwriting(config, client, image.getvalue())
    assert result["detail_review_completed"] is True
    assert result["detail_review_model"] == config.groq_vision_model
    assert result["detail_review_provider"] == "groq"
    assert result["requires_review"] is True
    assert "[uncertain: 500?]" in result["text"]
