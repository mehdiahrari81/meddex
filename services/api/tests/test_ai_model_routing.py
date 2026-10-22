"""Recovery must be bounded, quota-aware, source-safe and modality-safe."""

import json
from datetime import UTC, datetime, timedelta
from email.utils import format_datetime

import httpx
import pytest

from app.providers.ai import GeminiModelsUnavailable, GeminiProvider, provider_retry_delay
from app.providers.cloud_fallback import CloudProvider, CloudProvidersUnavailable
from tests.test_cloud_fallback import ANSWER, cloud, gemini_json, groq_json, settings

PRIMARY = "gemini-3.5-flash-lite"
SECONDARY = "gemini-3.1-flash-lite"
# Synthetic text-only model proves the configurable third slot, without enabling
# the real 2.5 endpoint which returned 404 in deployment checks.
EMERGENCY = "synthetic-emergency-text"


def generate(provider, **kwargs):
    return provider.generate_json_with_availability_fallback(
        fallback_model=PRIMARY,
        system_prompt="Use only the source.",
        text="Engineering fixture",
        schema={"type": "object"},
        **kwargs,
    )


def model(request):
    return request.url.path.rsplit("/", 1)[-1].split(":")[0]


def model_quota(name):
    return {
        "error": {
            "details": [
                {
                    "@type": "type.googleapis.com/google.rpc.QuotaFailure",
                    "violations": [
                        {
                            "quotaDimensions": {"model": name},
                            "quotaId": "GenerateRequestsPerDayPerProjectPerModel",
                        }
                    ],
                }
            ]
        }
    }


@pytest.mark.parametrize("failure", [408, 500, 501, 502, 503, 504, 599, "timeout", "connect"])
def test_primary_failure_recovers_once_on_secondary(failure):
    calls = []

    def respond(request):
        calls.append(model(request))
        if len(calls) == 1:
            if failure == "timeout":
                raise httpx.ReadTimeout("synthetic", request=request)
            if failure == "connect":
                raise httpx.ConnectError("synthetic", request=request)
            return httpx.Response(failure)
        return gemini_json({"ok": True})

    with httpx.Client(transport=httpx.MockTransport(respond)) as client:
        provider = cloud(client)
        assert json.loads(generate(provider)) == {"ok": True}
        assert provider.model == SECONDARY
        # A fresh request skips the failed primary until its cooldown expires.
        generate(cloud(client))
    assert calls == [PRIMARY, SECONDARY, SECONDARY]


def test_emergency_slot_then_groq_then_local_without_duplicate_models():
    from app.providers.ai import GeminiOllamaProvider, OllamaProvider, ProviderCooldown

    calls = []

    def respond(request):
        if request.url.host == "generativelanguage.googleapis.com":
            calls.append(model(request))
        elif request.url.host == "api.groq.com":
            calls.append("groq")
        else:
            calls.append("ollama")
            assert json.loads(request.content)["model"] == "qwen3:1.7b"
            assert request.extensions["timeout"]["read"] <= 30
            return httpx.Response(200, json={"message": {"content": json.dumps(ANSWER)}})
        return httpx.Response(503)

    with httpx.Client(transport=httpx.MockTransport(respond)) as client:
        config = settings(gemini_emergency_model=EMERGENCY)
        provider = GeminiOllamaProvider(
            primary=cloud(client, config),
            fallback=OllamaProvider(
                client=client,
                base_url="http://local.test",
                model=config.ollama_model,
            ),
            cooldown=ProviderCooldown(),
        )
        result = provider.explain(
            system_prompt="Use source.", context="SOURCE_ID=reference;", question="Explain"
        )
    assert result.provider == "ollama"
    assert calls == [PRIMARY, SECONDARY, EMERGENCY, "groq", "ollama"]


def test_model_quota_can_use_independently_available_model_and_cools_across_workflows():
    calls = []

    def respond(request):
        calls.append(model(request))
        if model(request) == PRIMARY:
            return httpx.Response(429, json=model_quota(PRIMARY), headers={"Retry-After": "90"})
        return gemini_json({"ok": True})

    with httpx.Client(transport=httpx.MockTransport(respond)) as client:
        generate(cloud(client))
        provider = CloudProvider(
            settings=settings(),
            client=client,
            model=PRIMARY,
            timeout_seconds=30,
            workflow="prescription",
        )
        generate(provider)
    assert calls == [PRIMARY, SECONDARY, SECONDARY]


@pytest.mark.parametrize("status", [402, 429, 503])
def test_global_limit_or_retry_after_skips_all_google_models_and_preserves_output(status):
    calls = []

    def respond(request):
        calls.append(request.url.host)
        if request.url.host == "generativelanguage.googleapis.com":
            return httpx.Response(status, headers={"Retry-After": "3600"})
        return groq_json({"ok": True})

    with httpx.Client(transport=httpx.MockTransport(respond)) as client:
        for _ in range(2):
            assert json.loads(generate(cloud(client))) == {"ok": True}
    assert calls == ["generativelanguage.googleapis.com", "api.groq.com", "api.groq.com"]


def test_mixed_quota_scopes_never_switch_google_models():
    calls = []

    def respond(request):
        calls.append(request.url.host)
        if len(calls) == 1:
            body = model_quota(PRIMARY)
            body["error"]["details"][0]["violations"].append({"quotaDimensions": {}})
            return httpx.Response(429, json=body)
        return groq_json({"ok": True})

    with httpx.Client(transport=httpx.MockTransport(respond)) as client:
        generate(cloud(client))
    assert calls == ["generativelanguage.googleapis.com", "api.groq.com"]


def test_image_chain_never_sends_images_to_text_only_models():
    calls = []

    def respond(request):
        if request.url.host == "generativelanguage.googleapis.com":
            calls.append(model(request))
            assert model(request) in {PRIMARY, SECONDARY}
            assert json.loads(request.content)["contents"][0]["parts"][0]["inlineData"]
            return httpx.Response(503)
        body = json.loads(request.content)
        calls.append(body["model"])
        assert body["model"] == settings().groq_vision_model
        assert body["messages"][1]["content"][0]["type"] == "image_url"
        return groq_json({"lines": []})

    with httpx.Client(transport=httpx.MockTransport(respond)) as client:
        config = settings(gemini_handwriting_emergency_model=EMERGENCY)
        assert json.loads(generate(cloud(client, config), image_bytes=b"synthetic")) == {
            "lines": []
        }
    assert calls == [PRIMARY, SECONDARY, settings().groq_vision_model]


def test_text_model_misconfigured_as_vision_is_skipped_safely():
    config = settings(gemini_handwriting_fallback_model="text-only", groq_vision_model="text-only")
    config.gemini_api_key = None
    with (
        httpx.Client(
            transport=httpx.MockTransport(lambda r: pytest.fail("Image leaked"))
        ) as client,
        pytest.raises(CloudProvidersUnavailable),
    ):
        generate(cloud(client, config), image_bytes=b"fixture")


def test_all_busy_models_are_not_probed_again_during_cooldown():
    calls = []

    def respond(request):
        calls.append(model(request))
        return httpx.Response(503)

    with httpx.Client(transport=httpx.MockTransport(respond)) as client:
        provider = GeminiProvider(client=client, model=PRIMARY, api_key="fixture")
        with pytest.raises(httpx.HTTPStatusError):
            generate(provider)
        provider.model = PRIMARY
        with pytest.raises(GeminiModelsUnavailable):
            generate(provider)
    assert calls == [PRIMARY]


def test_no_groq_still_uses_secondary_and_deduplicates_model_ids():
    config = settings(gemini_emergency_model=SECONDARY)
    config.groq_api_key = None
    calls = []

    def respond(request):
        calls.append(model(request))
        return httpx.Response(503) if len(calls) == 1 else gemini_json({"ok": True})

    with httpx.Client(transport=httpx.MockTransport(respond)) as client:
        assert json.loads(generate(cloud(client, config))) == {"ok": True}
    assert calls == [PRIMARY, SECONDARY]


def test_retry_after_http_date_and_google_retry_info():
    future = datetime.now(UTC) + timedelta(seconds=180)
    delay = provider_retry_delay(
        httpx.Response(
            429,
            headers={
                "Retry-After": format_datetime(future, usegmt=True),
            },
        ),
        300,
    )
    assert 178 <= delay <= 180
    assert (
        provider_retry_delay(
            httpx.Response(
                429,
                json={
                    "error": {
                        "details": [
                            {
                                "@type": "type.googleapis.com/google.rpc.RetryInfo",
                                "retryDelay": "120s",
                            }
                        ]
                    }
                },
            ),
            300,
        )
        == 120
    )


def test_separate_text_and_prescription_fallback_configuration():
    config = settings(gemini_prescription_fallback_model="synthetic-prescription-text")
    calls = []

    def respond(request):
        calls.append(model(request))
        return httpx.Response(503) if len(calls) == 1 else gemini_json({"ok": True})

    with httpx.Client(transport=httpx.MockTransport(respond)) as client:
        generate(
            CloudProvider(
                settings=config,
                client=client,
                model=PRIMARY,
                timeout_seconds=30,
                workflow="prescription",
            )
        )
    assert calls == [PRIMARY, "synthetic-prescription-text"]


def test_all_failures_share_cloud_budget_and_no_image_result_is_fabricated(monkeypatch):
    clock = [0.0]
    monkeypatch.setattr("app.providers.ai.time.monotonic", lambda: clock[0])
    calls = []

    def respond(request):
        timeout = request.extensions["timeout"]["read"]
        clock[0] += timeout
        calls.append(request.url.host)
        raise httpx.ReadTimeout("synthetic", request=request)

    with (
        httpx.Client(transport=httpx.MockTransport(respond)) as client,
        pytest.raises(CloudProvidersUnavailable),
    ):
        generate(cloud(client), image_bytes=b"synthetic")
    assert calls == ["generativelanguage.googleapis.com"] * 2 + ["api.groq.com"]
    assert clock[0] <= 30


def test_no_extra_requests_when_all_providers_are_cooling_down():
    calls = []

    def respond(request):
        calls.append(request.url.host)
        return httpx.Response(429, headers={"Retry-After": "3600"})

    with httpx.Client(transport=httpx.MockTransport(respond)) as client:
        for _ in range(3):
            with pytest.raises(CloudProvidersUnavailable) as error:
                generate(cloud(client))
            assert error.value.code == "cloud_limit_reached"
    assert calls == ["generativelanguage.googleapis.com", "api.groq.com"]


def test_retired_model_404_uses_secondary_and_is_not_retried():
    calls = []

    def respond(request):
        calls.append(model(request))
        return httpx.Response(404) if len(calls) == 1 else gemini_json({"ok": True})

    with httpx.Client(transport=httpx.MockTransport(respond)) as client:
        generate(cloud(client))
        generate(cloud(client))
    assert calls == [PRIMARY, SECONDARY, SECONDARY]


def test_project_quota_with_model_annotation_is_still_project_wide():
    calls = []

    def respond(request):
        calls.append(request.url.host)
        if len(calls) == 1:
            body = model_quota(PRIMARY)
            body["error"]["details"][0]["violations"][0]["quotaId"] = "RequestsPerProject"
            return httpx.Response(429, json=body)
        return groq_json({"ok": True})

    with httpx.Client(transport=httpx.MockTransport(respond)) as client:
        generate(cloud(client))
    assert calls == ["generativelanguage.googleapis.com", "api.groq.com"]


@pytest.mark.parametrize("status", [404, 501])
def test_no_groq_and_unavailable_google_models_still_use_local_text_fallback(status):
    from app.providers.ai import GeminiOllamaProvider, OllamaProvider, ProviderCooldown

    config = settings()
    config.groq_api_key = None
    calls = []

    def respond(request):
        calls.append(request.url.host)
        if request.url.host == "generativelanguage.googleapis.com":
            return httpx.Response(status)
        return httpx.Response(200, json={"message": {"content": json.dumps(ANSWER)}})

    with httpx.Client(transport=httpx.MockTransport(respond)) as client:
        provider = GeminiOllamaProvider(
            primary=cloud(client, config),
            fallback=OllamaProvider(
                client=client, base_url="http://local.test", model="qwen3:1.7b"
            ),
            cooldown=ProviderCooldown(),
        )
        result = provider.explain(
            system_prompt="Use source", context="SOURCE_ID=reference;", question="Explain"
        )
    assert result.provider == "ollama"
    assert calls == ["generativelanguage.googleapis.com"] * 2 + ["local.test"]
