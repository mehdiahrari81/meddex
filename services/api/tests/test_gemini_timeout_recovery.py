import json

import httpx
import pytest

from app.providers.ai import GeminiProvider


@pytest.mark.parametrize("budget,primary_time", [(60, 30), (30, 18)])
def test_read_timeout_uses_reserved_budget_for_alternate_model(monkeypatch, budget, primary_time):
    clock = [0.0]
    monkeypatch.setattr("app.providers.ai.time.monotonic", lambda: clock[0])
    requests = []

    def respond(request):
        requests.append(request)
        if len(requests) == 1:
            assert request.extensions["timeout"]["read"] == primary_time
            clock[0] += primary_time
            raise httpx.ReadTimeout("Synthetic delayed model", request=request)
        assert "gemini-3.5-flash:generateContent" in str(request.url)
        assert request.extensions["timeout"]["read"] == budget - primary_time
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

    with httpx.Client(transport=httpx.MockTransport(respond)) as http:
        provider = GeminiProvider(
            client=http, model="gemini-3.8-flash", api_key="qa", timeout_seconds=budget
        )
        result = provider.generate_json_with_availability_fallback(
            fallback_model="gemini-3.5-flash",
            system_prompt="Read only.",
            text="Fixture",
            schema={"type": "object"},
        )
    assert json.loads(result) == {"lines": []}
    assert len(requests) == 2
    assert provider.model == "gemini-3.5-flash"
    assert provider.timeout_seconds == budget


def test_two_timeouts_stop_without_more_requests():
    requests = []

    def respond(request):
        requests.append(request)
        raise httpx.ReadTimeout("Synthetic delayed models", request=request)

    with httpx.Client(transport=httpx.MockTransport(respond)) as http:
        provider = GeminiProvider(
            client=http, model="gemini-3.8-flash", api_key="qa", timeout_seconds=60
        )
        with pytest.raises(httpx.ReadTimeout):
            provider.generate_json_with_availability_fallback(
                fallback_model="gemini-3.5-flash",
                system_prompt="Read only.",
                text="Fixture",
                schema={"type": "object"},
            )
    assert len(requests) == 2


@pytest.mark.parametrize("status", [400, 401, 403, 429])
def test_invalid_credentials_and_quota_never_retry(status):
    requests = []

    def respond(request):
        requests.append(request)
        return httpx.Response(status)

    with httpx.Client(transport=httpx.MockTransport(respond)) as http:
        provider = GeminiProvider(
            client=http, model="gemini-3.8-flash", api_key="qa", timeout_seconds=60
        )
        with pytest.raises(httpx.HTTPStatusError):
            provider.generate_json_with_availability_fallback(
                fallback_model="gemini-3.5-flash",
                system_prompt="Read only.",
                text="Fixture",
                schema={"type": "object"},
            )
    assert len(requests) == 1
