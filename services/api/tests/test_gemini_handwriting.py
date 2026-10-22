import base64
import io
import json

import httpx
from PIL import Image
from pydantic import SecretStr

from app.core.config import Settings
from app.services.gemini_handwriting import transcribe_handwriting
from tests.conftest import auth_headers


def image():
    output = io.BytesIO()
    Image.new("RGB", (300, 100), "white").save(output, format="PNG")
    return output.getvalue()


def test_gemini_image_transcription_preserves_uncertainty_and_strips_metadata():
    original = io.BytesIO()
    metadata = Image.Exif()
    metadata[315] = "Private camera metadata fixture"
    Image.new("RGB", (300, 100), "white").save(original, format="JPEG", exif=metadata)
    assert Image.open(io.BytesIO(original.getvalue())).getexif()[315]

    def respond(request):
        body = json.loads(request.content)
        parts = body["contents"][0]["parts"]
        pixels = base64.b64decode(parts[0]["inlineData"]["data"])
        assert Image.open(io.BytesIO(pixels)).format == "JPEG"
        assert Image.open(io.BytesIO(pixels)).getexif() == {}
        assert parts[0]["inlineData"]["mimeType"] == "image/jpeg"
        assert body["generationConfig"]["mediaResolution"] == "MEDIA_RESOLUTION_HIGH"
        assert request.headers["x-goog-api-key"] == "qa-private-key"
        return httpx.Response(
            200,
            json={
                "candidates": [
                    {
                        "finishReason": "STOP",
                        "content": {
                            "parts": [
                                {
                                    "text": json.dumps(
                                        {
                                            "lines": [
                                                {"text": "Betaloc 50 mg BD", "uncertain": False},
                                                {"text": "unclear? 5? mg", "uncertain": True},
                                            ]
                                        }
                                    )
                                }
                            ]
                        },
                    }
                ]
            },
        )

    with httpx.Client(transport=httpx.MockTransport(respond)) as client:
        result = transcribe_handwriting(
            Settings(gemini_api_key=SecretStr("qa-private-key")), client, original.getvalue()
        )
    assert result["text"] == "Betaloc 50 mg BD\nunclear? 5? mg [?]"
    assert result["uncertain_line_numbers"] == [2]
    assert result["requires_review"] is True


def test_image_endpoint_requires_login_and_separate_explicit_image_consent(
    client, registered, monkeypatch
):
    path = "/api/v1/prescription-ocr/handwriting/gemini"
    assert client.post(path, content=image()).status_code == 401
    headers = auth_headers(registered["access_token"]) | {"Content-Type": "image/png"}
    assert client.post(path, headers=headers, content=image()).status_code == 422
    assert (
        client.post(
            path, headers=headers | {"X-Cloud-Consent": "false"}, content=image()
        ).status_code
        == 422
    )

    def recognize(settings, http, payload):
        assert payload == image()
        return {
            "text": "Betaloc 50 mg BD",
            "requires_review": True,
            "model": "qa",
            "revision": "qa",
        }

    monkeypatch.setattr("app.api.v1.routers.prescription_ocr.transcribe_handwriting", recognize)
    response = client.post(path, headers=headers | {"X-Cloud-Consent": "true"}, content=image())
    assert response.status_code == 200
    assert response.headers["cache-control"] == "no-store"
    assert response.json()["requires_review"] is True
    assert (
        client.post(
            path, headers=headers | {"X-Cloud-Consent": "true"}, content=b"x" * 6_000_001
        ).status_code
        == 413
    )


def test_uncertainty_is_attached_to_the_written_span_not_every_field(monkeypatch):
    from app.providers.ai import GeminiProvider

    def generate(self, **kwargs):
        assert kwargs["high_resolution"] is True
        return json.dumps(
            {
                "lines": [
                    {"text": "Betaloc 50 mg BD", "uncertain": True, "uncertain_spans": ["50 mg"]}
                ]
            }
        )

    monkeypatch.setattr(GeminiProvider, "generate_json", generate)
    with httpx.Client() as http:
        result = transcribe_handwriting(Settings(), http, image())
    assert result["text"] == "Betaloc [uncertain: 50 mg] BD"
    assert "[?]" not in result["text"]
    assert result["uncertain_line_numbers"] == [1]
