"""Gemini-first cloud requests with a bounded Groq fallback and shared quota backoff."""

import base64
import hashlib
import re
import time
from dataclasses import replace
from typing import Any, Literal

import httpx

from app.core.config import Settings
from app.core.errors import AppException
from app.core.logging import get_logger
from app.providers.ai import (
    ExplanationPayload,
    GeminiModelsUnavailable,
    GeminiProvider,
    GeneratedExplanation,
    ProviderCooldown,
    _parse_explanation,
    provider_retry_delay,
    shared_cooldown,
)


class CloudProvidersUnavailable(AppException):
    def __init__(self, reason: str):
        super().__init__(
            "cloud_limit_reached" if reason == "quota" else "cloud_temporarily_unavailable",
            "Cloud providers are temporarily unavailable. Your saved scan can be retried.",
            status_code=503,
        )
        self.reason = reason


class CloudProvider(GeminiProvider):
    """Retains Gemini's interface and validation; no prompt/image is cached by backoff."""

    manages_availability = True

    def __init__(
        self,
        *,
        settings: Settings,
        client: httpx.Client,
        model: str,
        timeout_seconds: float,
        vision: bool = False,
        workflow: Literal["text", "prescription", "handwriting"] = "text",
    ):
        super().__init__(
            client=client,
            model=model,
            api_key=settings.gemini_api_key.get_secret_value() if settings.gemini_api_key else None,
            timeout_seconds=timeout_seconds,
        )
        self.settings = settings
        self.vision = vision
        self.workflow = "handwriting" if vision else workflow
        self.cooldown_seconds = settings.gemini_cooldown_seconds
        self.gemini_model = model
        self.groq_model = settings.groq_vision_model if vision else settings.groq_model
        self.used_provider: Literal["gemini", "groq"] = "gemini"
        self.fallback_reason: str | None = None

    @property
    def configured(self) -> bool:
        return bool(self.api_key or self.settings.groq_api_key)

    def explain(self, *, system_prompt: str, context: str, question: str) -> GeneratedExplanation:
        schema = ExplanationPayload.model_json_schema()
        # Same source-ID constraints are applied to both providers.
        ids = list(dict.fromkeys(re.findall(r"SOURCE_ID=([^;\s]+)", context)))
        if ids:
            schema["properties"]["source_ids"]["items"]["enum"] = ids
        content = self.generate_json_with_availability_fallback(
            fallback_model=self.gemini_model,
            system_prompt=system_prompt,
            text=f"TRUSTED DATA:\n{context}\n\nQUESTION:\n{question}",
            schema=schema,
        )
        return replace(
            _parse_explanation(content),
            provider=self.used_provider,
            model=self.model,
            fallback_reason=self.fallback_reason,
        )

    def generate_json_with_availability_fallback(self, **kwargs: Any) -> str:
        started = time.monotonic()
        budget = self.timeout_seconds
        self.model = self.gemini_model
        self.fallback_reason = None
        image = bool(kwargs.get("image_bytes"))
        workflow = "handwriting" if image else self.workflow
        prefix = "gemini" if workflow == "text" else "gemini_" + workflow
        # Route by workflow, not the caller's duplicated primary-as-fallback value.
        kwargs["fallback_model"] = getattr(self.settings, prefix + "_fallback_model")
        kwargs["recovery_model"] = getattr(self.settings, prefix + "_emergency_model") or None
        reason = "gemini_not_configured"
        if self.api_key:
            # Reserve a bounded portion for Groq; a successful primary adds no extra calls.
            self.timeout_seconds = min(12, budget * 0.6) if self.settings.groq_api_key else budget
            try:
                result = super().generate_json_with_availability_fallback(**kwargs)
                self.used_provider = "gemini"
                if self.model != self.gemini_model:
                    self.fallback_reason = "gemini_unavailable"
                return result
            except GeminiModelsUnavailable as error:
                reason = error.reason
            except (httpx.HTTPStatusError, httpx.TransportError) as error:
                if not self.settings.groq_api_key:
                    raise  # Retain existing Gemini-only error contracts.
                status = (
                    error.response.status_code if isinstance(error, httpx.HTTPStatusError) else None
                )
                if (
                    status is not None
                    and status not in {402, 404, 408, 429}
                    and not (500 <= status <= 599)
                ):
                    raise
                reason = "gemini_quota_exhausted" if status in {402, 429} else "gemini_unavailable"
            finally:
                self.timeout_seconds = budget
        if not self.settings.groq_api_key:
            raise CloudProvidersUnavailable("quota" if "quota" in reason else "availability")
        # Images are never sent to the configured text model, even on a text instance.
        self.groq_model = self.settings.groq_vision_model if image else self.settings.groq_model
        if image and self.groq_model not in GROQ_IMAGE_MODELS:
            raise CloudProvidersUnavailable("availability")
        groq_key = self.settings.groq_api_key.get_secret_value()
        groq_state = shared_cooldown(self._fingerprint(groq_key), "groq:" + self.groq_model)
        global_state = shared_cooldown(self._fingerprint(groq_key), "groq:*")
        blocked = global_state.reason() or groq_state.reason()
        if blocked is not None:
            raise CloudProvidersUnavailable("quota" if "quota" in blocked else "availability")
        remaining = budget - (time.monotonic() - started)
        if remaining <= 0:
            raise CloudProvidersUnavailable("availability")
        try:
            content = self._groq_json(
                timeout=min(remaining, self.settings.groq_timeout_seconds), **kwargs
            )
        except (httpx.HTTPStatusError, httpx.TransportError) as error:
            blocked = self._backoff(error, groq_state, "groq")
            if isinstance(error, httpx.HTTPStatusError) and (
                error.response.status_code in {402, 429}
                or error.response.headers.get("retry-after")
            ):
                global_state.block(
                    provider_retry_delay(error.response, self.settings.groq_cooldown_seconds),
                    blocked,
                )
            raise CloudProvidersUnavailable(
                "quota" if "quota" in blocked else "availability"
            ) from None
        self.used_provider = "groq"
        self.model = self.groq_model
        self.fallback_reason = reason
        get_logger().info(
            "ai_provider_recovered",
            workflow=workflow,
            provider="groq",
            model=self.model,
            reason=reason,
        )
        return content

    @staticmethod
    def _fingerprint(key: str | None) -> str:
        return hashlib.sha256((key or "").encode()).hexdigest()

    def _backoff(self, error: httpx.HTTPError, state: ProviderCooldown, provider: str) -> str:
        status = error.response.status_code if isinstance(error, httpx.HTTPStatusError) else None
        if status is not None and status not in {402, 404, 429, 408} and not 500 <= status <= 599:
            raise error  # Invalid credentials, permission blocks and bad requests are not quotas.
        reason = (
            f"{provider}_quota_exhausted" if status in {402, 429} else f"{provider}_unavailable"
        )
        # Reuse existing Retry-After seconds/date/Google RetryInfo parsing.
        default = (
            self.settings.gemini_cooldown_seconds
            if provider == "gemini"
            else self.settings.groq_cooldown_seconds
        )
        delay = (
            provider_retry_delay(error.response, default)
            if isinstance(error, httpx.HTTPStatusError)
            else 15
        )
        state.block(delay, reason)
        return reason

    def _groq_json(self, *, timeout: float, **kwargs: Any) -> str:
        content: list[dict[str, Any]] = []
        image = kwargs.get("image_bytes")
        if image:
            # Always retain the entire page, with bounded contextual crops.
            crops = kwargs.get("additional_images") or []
            limit = self.settings.groq_vision_max_images
            if limit == 3 and len(crops) > 2:
                # Cover both ends of a tall prescription, including its final
                # medicine, rather than spending both detail images at the top.
                crops = [crops[0], crops[-1]]
            images = [image, *crops][:limit]
            for pixels in images:
                content.append(
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": "data:"
                            + kwargs.get("image_mime_type", "image/jpeg")
                            + ";base64,"
                            + base64.b64encode(pixels).decode("ascii")
                        },
                    }
                )
        content.append({"type": "text", "text": kwargs["text"]})
        key = self.settings.groq_api_key
        if key is None:
            raise RuntimeError("groq_not_configured")
        response = self.client.post(
            "https://api.groq.com/openai/v1/chat/completions",
            headers={"Authorization": "Bearer " + key.get_secret_value()},
            timeout=timeout,
            json={
                "model": self.groq_model,
                "temperature": 0,
                "reasoning_effort": "low"
                if self.groq_model.startswith("openai/gpt-oss")
                else "none",
                "max_completion_tokens": min(
                    kwargs.get("max_tokens", 2048),
                    self.settings.groq_vision_max_output_tokens
                    if image
                    else self.settings.groq_max_output_tokens,
                ),
                "messages": [
                    {
                        "role": "system",
                        "content": kwargs["system_prompt"] + " Return compact JSON.",
                    },
                    {"role": "user", "content": content},
                ],
                "response_format": {
                    "type": "json_schema",
                    "json_schema": {
                        "name": "medical_result",
                        "strict": True,
                        "schema": kwargs["schema"],
                    },
                },
            },
        )
        response.raise_for_status()
        choice = response.json()["choices"][0]
        if choice.get("finish_reason") != "stop" or choice["message"].get("refusal"):
            raise ValueError("groq_blocked_or_incomplete")
        result = choice["message"].get("content")
        if not isinstance(result, str) or not result.strip():
            raise ValueError("groq_empty_result")
        return result


# Verified against Groq documentation and a live synthetic-image request.
GROQ_IMAGE_MODELS = frozenset({"qwen/qwen3.8-27b"})
