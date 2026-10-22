"""Regression coverage for Google high-demand failures seen on the device."""

import json

import httpx
import pytest

from app.providers.ai import GeminiProvider
from tests.conftest import auth_headers

MODELS = ["gemini-3.8-flash", "gemini-3.5-flash", "gemini-3.5-flash-lite"]


def success():
    return httpx.Response(
        200,
        json={
            "candidates": [
                {
                    "finishReason": "STOP",
                    "content": {"parts": [{"text": json.dumps({"lines": []})}]},
                }
            ]
        },
    )


def read(provider):
    return provider.generate_json_with_availability_fallback(
        fallback_model=MODELS[1],
        recovery_model=MODELS[2],
        system_prompt="Transcribe without guessing.",
        text="Synthetic fixture",
        schema={"type": "object"},
    )


def test_two_busy_models_recover_and_next_scan_skips_them_until_cooldown_expires(monkeypatch):
    clock = [0.0]
    delays = []
    calls = []
    monkeypatch.setattr("app.providers.ai.time.monotonic", lambda: clock[0])

    def sleep(seconds):
        delays.append(seconds)
        clock[0] += seconds

    monkeypatch.setattr("app.providers.ai.time.sleep", sleep)

    def respond(request):
        model = request.url.path.split("/")[-1].split(":")[0]
        calls.append(model)
        return httpx.Response(503) if model != MODELS[2] and clock[0] < 120 else success()

    with httpx.Client(transport=httpx.MockTransport(respond)) as client:

        def provider():
            return GeminiProvider(client=client, model=MODELS[0], api_key="qa", timeout_seconds=60)

        first = provider()
        assert json.loads(read(first)) == {"lines": []}
        assert first.model == MODELS[2]
        assert calls == MODELS
        assert delays == []
        assert first.timeout_seconds == 60
        read(provider())
        assert calls == [*MODELS, MODELS[2]]
        clock[0] = 301
        read(provider())
        assert calls[-1] == MODELS[0]


@pytest.mark.parametrize("budget,expected", [(60, [24, 21.6, 14.4]), (30, [12, 10.8, 7.2])])
def test_all_timeouts_and_backoff_share_one_budget(monkeypatch, budget, expected):
    clock = [0.0]
    timeouts = []
    monkeypatch.setattr("app.providers.ai.time.monotonic", lambda: clock[0])
    monkeypatch.setattr(
        "app.providers.ai.time.sleep", lambda seconds: clock.__setitem__(0, clock[0] + seconds)
    )

    def respond(request):
        timeout = request.extensions["timeout"]["read"]
        timeouts.append(timeout)
        clock[0] += timeout
        raise httpx.ReadTimeout("Synthetic timeout", request=request)

    with httpx.Client(transport=httpx.MockTransport(respond)) as client:
        provider = GeminiProvider(
            client=client, model=MODELS[0], api_key="qa", timeout_seconds=budget
        )
        with pytest.raises(httpx.ReadTimeout):
            read(provider)
    assert timeouts == pytest.approx(expected)
    assert clock[0] <= budget
    assert provider.timeout_seconds == budget


@pytest.mark.parametrize("status", [400, 401, 402, 403, 429])
def test_configuration_and_quota_errors_never_use_another_model(status):
    calls = []

    def respond(request):
        calls.append(request)
        return httpx.Response(status)

    with httpx.Client(transport=httpx.MockTransport(respond)) as client:
        provider = GeminiProvider(client=client, model=MODELS[0], api_key="qa")
        with pytest.raises(httpx.HTTPStatusError):
            read(provider)
    assert len(calls) == 1


def test_all_busy_models_stop_after_three_calls():
    calls = []

    def respond(request):
        calls.append(request)
        return httpx.Response(503)

    with httpx.Client(transport=httpx.MockTransport(respond)) as client:
        provider = GeminiProvider(client=client, model=MODELS[0], api_key="qa", timeout_seconds=60)
        with pytest.raises(httpx.HTTPStatusError):
            read(provider)
    assert len(calls) == 3


@pytest.mark.parametrize("retry_after", ["4", "120"])
def test_retry_after_pauses_provider_without_sleeping_or_exceeding_budget(monkeypatch, retry_after):
    delays = []
    calls = []
    monkeypatch.setattr("app.providers.ai.time.sleep", delays.append)

    def respond(request):
        calls.append(request)
        return httpx.Response(503, headers={"Retry-After": retry_after})

    with httpx.Client(transport=httpx.MockTransport(respond)) as client:
        provider = GeminiProvider(client=client, model=MODELS[0], api_key="qa", timeout_seconds=60)
        with pytest.raises(httpx.HTTPStatusError):
            read(provider)
    assert len(calls) == 1
    assert not delays


@pytest.mark.parametrize("finish_reason", ["SAFETY", "MAX_TOKENS"])
def test_invalid_or_blocked_output_never_triggers_another_model(finish_reason):
    calls = []

    def respond(request):
        calls.append(request)
        return httpx.Response(200, json={"candidates": [{"finishReason": finish_reason}]})

    with httpx.Client(transport=httpx.MockTransport(respond)) as client:
        provider = GeminiProvider(client=client, model=MODELS[0], api_key="qa")
        with pytest.raises(ValueError):
            read(provider)
    assert len(calls) == 1


def test_image_busy_response_has_specific_safe_error(client, registered, monkeypatch):
    def busy(*args):
        request = httpx.Request("POST", "https://example.com/fixture")
        response = httpx.Response(503, request=request)
        raise httpx.HTTPStatusError("private upstream detail", request=request, response=response)

    monkeypatch.setattr("app.api.v1.routers.prescription_ocr.transcribe_handwriting", busy)
    response = client.post(
        "/api/v1/prescription-ocr/handwriting/gemini",
        content=b"fixture",
        headers={
            **auth_headers(registered["access_token"]),
            "Content-Type": "image/jpeg",
            "X-Cloud-Consent": "true",
        },
    )
    assert response.status_code == 503
    assert response.json()["error"]["code"] == "gemini_temporarily_busy"
    assert "private upstream detail" not in response.text
