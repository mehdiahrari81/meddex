import json

import httpx
import pytest
from pydantic import SecretStr

from app.core.config import Settings
from app.providers.ai import GeminiOllamaProvider, GeminiProvider, OllamaProvider, ProviderCooldown

OUTPUT = {"answer": "Read the official source.", "mentioned_medications": [], "source_ids": ["s1"]}


def provider(
    client: httpx.Client, state: ProviderCooldown, key: str | None = "test-key"
) -> GeminiOllamaProvider:
    return GeminiOllamaProvider(
        primary=GeminiProvider(client=client, model="gemini-3.5-flash-lite", api_key=key),
        fallback=OllamaProvider(
            client=client, base_url="http://ollama.test:11434", model="qwen3:8b"
        ),
        cooldown=state,
        cooldown_seconds=300,
    )


def explain(ai: GeminiOllamaProvider):
    return ai.explain(
        system_prompt="Use only references.",
        context="SOURCE_ID=s1; official text",
        question="Explain the source.",
    )


def test_gemini_is_first_and_key_never_appears_in_url() -> None:
    def respond(request: httpx.Request) -> httpx.Response:
        assert request.url.host == "generativelanguage.googleapis.com"
        assert "test-key" not in str(request.url)
        assert request.headers["x-goog-api-key"] == "test-key"
        body = json.loads(request.content)
        assert body["generationConfig"]["responseFormat"]["text"]["mimeType"] == "APPLICATION_JSON"
        schema = body["generationConfig"]["responseFormat"]["text"]["schema"]
        assert schema["properties"]["source_ids"]["items"]["enum"] == ["s1"]
        assert body["systemInstruction"]["parts"][0]["text"] == "Use only references."
        return httpx.Response(
            200,
            json={
                "candidates": [
                    {"finishReason": "STOP", "content": {"parts": [{"text": json.dumps(OUTPUT)}]}}
                ]
            },
        )

    with httpx.Client(transport=httpx.MockTransport(respond)) as client:
        result = explain(provider(client, ProviderCooldown()))
    assert result.provider == "gemini"
    assert result.fallback_reason is None


@pytest.mark.parametrize("quota_status", [402, 429])
def test_quota_falls_back_across_instances_then_retries_gemini_after_reset(
    quota_status: int,
) -> None:
    clock = [10.0]
    state = ProviderCooldown(clock=lambda: clock[0])
    calls = []

    def respond(request: httpx.Request) -> httpx.Response:
        calls.append(request.url.host)
        if request.url.host == "generativelanguage.googleapis.com":
            if calls.count(request.url.host) == 1:
                return httpx.Response(
                    quota_status,
                    headers={"Retry-After": "60"},
                    json={"error": {"status": "RESOURCE_EXHAUSTED"}},
                )
            return httpx.Response(
                200,
                json={
                    "candidates": [
                        {
                            "finishReason": "STOP",
                            "content": {"parts": [{"text": json.dumps(OUTPUT)}]},
                        }
                    ]
                },
            )
        return httpx.Response(200, json={"message": {"content": json.dumps(OUTPUT)}})

    with httpx.Client(transport=httpx.MockTransport(respond)) as client:
        for _ in range(2):
            result = explain(provider(client, state))
            assert result.provider == "ollama"
            assert result.fallback_reason == "gemini_quota_exhausted"
        assert calls == ["generativelanguage.googleapis.com", "ollama.test", "ollama.test"]
        clock[0] += 61
        assert explain(provider(client, state)).provider == "gemini"


@pytest.mark.parametrize("status", [400, 401, 403, 404])
def test_bad_keys_or_model_configuration_are_not_treated_as_exhausted_quota(status: int) -> None:
    def respond(request: httpx.Request) -> httpx.Response:
        assert request.url.host == "generativelanguage.googleapis.com"
        return httpx.Response(status, json={"error": {"status": "INVALID_ARGUMENT"}})

    with (
        httpx.Client(transport=httpx.MockTransport(respond)) as client,
        pytest.raises(httpx.HTTPStatusError),
    ):
        explain(provider(client, ProviderCooldown()))


@pytest.mark.parametrize("finish", ["SAFETY", "MAX_TOKENS"])
def test_blocked_or_truncated_output_cannot_bypass_safety_via_fallback(finish: str) -> None:
    def respond(request: httpx.Request) -> httpx.Response:
        assert request.url.host == "generativelanguage.googleapis.com"
        return httpx.Response(200, json={"candidates": [{"finishReason": finish}]})

    with (
        httpx.Client(transport=httpx.MockTransport(respond)) as client,
        pytest.raises(ValueError, match="blocked_or_incomplete"),
    ):
        explain(provider(client, ProviderCooldown()))


def test_both_providers_unavailable_propagates_to_existing_source_fallback() -> None:
    def respond(request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            429 if request.url.host == "generativelanguage.googleapis.com" else 503
        )

    with (
        httpx.Client(transport=httpx.MockTransport(respond)) as client,
        pytest.raises(httpx.HTTPStatusError),
    ):
        explain(provider(client, ProviderCooldown()))


def test_missing_gemini_key_uses_local_model_and_settings_hide_key() -> None:
    def respond(request: httpx.Request) -> httpx.Response:
        assert request.url.host == "ollama.test"
        return httpx.Response(200, json={"message": {"content": json.dumps(OUTPUT)}})

    with httpx.Client(transport=httpx.MockTransport(respond)) as client:
        result = explain(provider(client, ProviderCooldown(), key=None))
        assert result.fallback_reason == "gemini_not_configured"
    settings = Settings(gemini_api_key=SecretStr("private-secret"))
    assert "private-secret" not in repr(settings)


def test_google_retry_info_is_respected() -> None:
    with httpx.Client() as client:
        ai = provider(client, ProviderCooldown())
        response = httpx.Response(
            429,
            json={
                "error": {
                    "details": [
                        {"@type": "type.googleapis.com/google.rpc.RetryInfo", "retryDelay": "3600s"}
                    ]
                }
            },
        )
        assert ai._retry_after(response) == 3600


def test_quota_fallback_still_passes_rag_grounding_and_reports_actual_provider(
    client, registered
) -> None:
    from uuid import UUID

    from sqlalchemy import select

    from app.models import FeatureFlag, MedicationIdentity, ProviderHealthEvent
    from app.schemas.intelligence import AiQuestionRequest
    from app.services.medical_rag import MedicalRagService
    from tests.test_intelligence import _grounded_medication

    medication = _grounded_medication(client)
    settings = client.app.state.settings
    settings.ai_provider = "gemini_ollama"
    settings.gemini_api_key = SecretStr("rag-integration-test-key")
    settings.ollama_base_url = "http://ollama.test:11434"
    with client.app.state.session_factory() as db:
        db.get(FeatureFlag, "ai_assistant").enabled = True
        db.commit()
        fact = db.get(MedicationIdentity, medication.id).facts[0]

        def respond(request: httpx.Request) -> httpx.Response:
            if request.url.host == "generativelanguage.googleapis.com":
                return httpx.Response(429)
            return httpx.Response(
                200,
                json={
                    "message": {
                        "content": json.dumps(
                            {
                                "answer": (
                                    "The source says to read the official patient information."
                                ),
                                "mentioned_medications": [],
                                "source_ids": [str(fact.id)],
                            }
                        )
                    }
                },
            )

        with httpx.Client(transport=httpx.MockTransport(respond)) as transport:
            result = MedicalRagService(db, settings, client=transport).answer(
                user_id=UUID(registered["user_id"]),
                request=AiQuestionRequest(
                    question="Explain the warnings", medication_id=medication.id
                ),
            )
        assert result.ai_provider_used is True
        assert result.generation_provider == "ollama"
        assert result.provider_fallback_reason == "gemini_quota_exhausted"
        assert not any("Gemini's usage limit" in text for text in result.limitations)
        assert db.scalar(select(ProviderHealthEvent)).provider == "ai_ollama"
