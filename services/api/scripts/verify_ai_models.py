"""Explicit operator check; uses synthetic data and never prints credentials/prompts.

Run from any directory with services/api/.venv/bin/python. This makes small live
API requests (quota/billing applies). It never enables models or changes config.
"""

import base64
import io
import json
import sys
from pathlib import Path

import httpx
from PIL import Image, ImageDraw

API_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(API_ROOT))

from app.core.config import Settings  # noqa: E402


def emit(**values: object) -> None:
    print(json.dumps(values), flush=True)


def main() -> None:
    settings = Settings(_env_file=API_ROOT / ".env")
    image = Image.new("RGB", (500, 180), "white")
    ImageDraw.Draw(image).text((20, 50), "TEST CODE 123", fill="black", font_size=36)
    buffer = io.BytesIO()
    image.save(buffer, format="PNG")
    pixels = base64.b64encode(buffer.getvalue()).decode("ascii")
    schema = {
        "type": "object",
        "properties": {"text": {"type": "string"}},
        "required": ["text"],
        "additionalProperties": False,
    }
    # Include the requested emergency ID in diagnostics even when disabled.
    models = list(
        dict.fromkeys(
            [
                settings.gemini_model,
                settings.gemini_fallback_model,
                settings.gemini_emergency_model or "gemini-2.5-flash-lite",
            ]
        )
    )
    with httpx.Client(timeout=25) as client:
        if settings.gemini_api_key:
            headers = {"x-goog-api-key": settings.gemini_api_key.get_secret_value()}
            stop_google = False
            for model in models:
                if stop_google:
                    break
                url = "https://generativelanguage.googleapis.com/v1beta/models/" + model
                try:
                    response = client.get(url, headers=headers)
                    emit(
                        provider="gemini",
                        model=model,
                        catalog_status=response.status_code,
                        methods=response.json().get("supportedGenerationMethods", []),
                    )
                    if response.status_code == 429:
                        break
                    if response.status_code != 200:
                        continue
                    for vision in (False, True):
                        parts = (
                            [{"inlineData": {"mimeType": "image/png", "data": pixels}}]
                            if vision
                            else []
                        )
                        parts.append(
                            {
                                "text": "Return JSON with text containing the test code "
                                "in the image."
                                if vision
                                else "Return JSON with text equal to OK."
                            }
                        )
                        response = client.post(
                            url + ":generateContent",
                            headers=headers,
                            json={
                                "contents": [{"parts": parts}],
                                "generationConfig": {
                                    "maxOutputTokens": 100,
                                    "responseFormat": {
                                        "text": {
                                            "mimeType": "APPLICATION_JSON",
                                            "schema": schema,
                                        }
                                    },
                                },
                            },
                        )
                        candidates = response.json().get("candidates") or [{}]
                        parts_out = candidates[0].get("content", {}).get("parts", [])
                        output = "".join(p.get("text", "") for p in parts_out)
                        valid = False
                        if response.status_code == 200:
                            parsed = json.loads(output)
                            valid = (
                                "123" in parsed.get("text", "")
                                if vision
                                else (parsed.get("text", "").upper() == "OK")
                            )
                        emit(
                            provider="gemini",
                            model=model,
                            vision=vision,
                            status=response.status_code,
                            valid_result=valid,
                            finish=candidates[0].get("finishReason"),
                        )
                        if response.status_code == 429:
                            stop_google = True
                            break  # Never probe other models after an unknown quota error.
                except (httpx.HTTPError, ValueError, KeyError, TypeError) as error:
                    emit(provider="gemini", model=model, error_type=type(error).__name__)
        if settings.groq_api_key:
            headers = {"Authorization": "Bearer " + settings.groq_api_key.get_secret_value()}
            for model, vision in [(settings.groq_model, False), (settings.groq_vision_model, True)]:
                try:
                    content = (
                        [
                            {
                                "type": "image_url",
                                "image_url": {
                                    "url": "data:image/png;base64," + pixels,
                                },
                            }
                        ]
                        if vision
                        else []
                    )
                    content.append(
                        {
                            "type": "text",
                            "text": "Return JSON with text containing the code in the image."
                            if vision
                            else "Return JSON with text equal to OK.",
                        }
                    )
                    response = client.post(
                        "https://api.groq.com/openai/v1/chat/completions",
                        headers=headers,
                        json={
                            "model": model,
                            "messages": [{"role": "user", "content": content}],
                            "max_completion_tokens": 150,
                            "reasoning_effort": "none" if vision else "low",
                            "response_format": {
                                "type": "json_schema",
                                "json_schema": {
                                    "name": "probe",
                                    "strict": True,
                                    "schema": schema,
                                },
                            },
                        },
                    )
                    valid = False
                    choices = response.json().get("choices") or [{}]
                    if response.status_code == 200:
                        parsed = json.loads(choices[0]["message"]["content"])
                        valid = (
                            "123" in parsed.get("text", "")
                            if vision
                            else (parsed.get("text", "").upper() == "OK")
                        )
                    emit(
                        provider="groq",
                        model=model,
                        vision=vision,
                        status=response.status_code,
                        valid_result=valid,
                        finish=choices[0].get("finish_reason"),
                    )
                    if response.status_code == 429:
                        break
                except (httpx.HTTPError, ValueError, KeyError, TypeError) as error:
                    emit(provider="groq", model=model, error_type=type(error).__name__)
        try:
            response = client.get(settings.ollama_base_url.rstrip("/") + "/api/tags")
            installed = [entry["name"] for entry in response.json().get("models", [])]
            emit(
                provider="ollama",
                model=settings.ollama_model,
                installed=settings.ollama_model in installed,
                status=response.status_code,
            )
        except (httpx.HTTPError, ValueError, KeyError, TypeError) as error:
            emit(provider="ollama", error_type=type(error).__name__)


if __name__ == "__main__":
    main()
