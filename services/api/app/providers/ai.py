import base64
import hashlib
import re
import threading
import time
from abc import ABC, abstractmethod
from collections.abc import Callable
from dataclasses import dataclass, replace
from datetime import UTC, datetime
from email.utils import parsedate_to_datetime
from functools import lru_cache

import httpx
from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.core.errors import AppException
from app.core.logging import get_logger


class ExplanationPayload(BaseModel):
    model_config = ConfigDict(strict=True, extra="forbid")

    answer: str = Field(min_length=1, max_length=4000)
    mentioned_medications: list[str] = Field(max_length=20)
    source_ids: list[str] = Field(min_length=1, max_length=8)

    @field_validator("answer")
    @classmethod
    def nonempty_answer(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("model_response_empty")
        return value.strip()


def _parse_explanation(content: object) -> "GeneratedExplanation":
    if not isinstance(content, str):
        raise ValueError("model_response_invalid")
    parsed = ExplanationPayload.model_validate_json(content)
    return GeneratedExplanation(
        answer=parsed.answer,
        mentioned_medications=tuple(parsed.mentioned_medications),
        source_ids=tuple(parsed.source_ids),
    )


@dataclass(frozen=True)
class GeneratedExplanation:
    answer: str
    mentioned_medications: tuple[str, ...]
    source_ids: tuple[str, ...]
    provider: str | None = None
    model: str | None = None
    fallback_reason: str | None = None


class AiExplanationProvider(ABC):
    @property
    @abstractmethod
    def configured(self) -> bool: ...

    @abstractmethod
    def explain(
        self, *, system_prompt: str, context: str, question: str
    ) -> GeneratedExplanation: ...


class DisabledAiProvider(AiExplanationProvider):
    @property
    def configured(self) -> bool:
        return False

    def explain(self, *, system_prompt: str, context: str, question: str) -> GeneratedExplanation:
        raise RuntimeError("ai_provider_disabled")


class OpenAiCompatibleProvider(AiExplanationProvider):
    def __init__(self, *, client: httpx.Client, base_url: str, model: str, api_key: str | None):
        self.client = client
        self.base_url = base_url.rstrip("/")
        self.model = model
        self.api_key = api_key

    @property
    def configured(self) -> bool:
        return True

    def explain(self, *, system_prompt: str, context: str, question: str) -> GeneratedExplanation:
        headers = {"Authorization": f"Bearer {self.api_key}"} if self.api_key else {}
        base = self.base_url if self.base_url.endswith("/v1") else f"{self.base_url}/v1"
        response = self.client.post(
            f"{base}/chat/completions",
            headers=headers,
            json={
                "model": self.model,
                "temperature": 0,
                "response_format": {"type": "json_object"},
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {
                        "role": "user",
                        "content": f"TRUSTED DATA:\n{context}\n\nQUESTION:\n{question}",
                    },
                ],
            },
        )
        response.raise_for_status()
        content = response.json()["choices"][0]["message"]["content"]
        return replace(_parse_explanation(content), provider="openai_compatible", model=self.model)


class OllamaProvider(AiExplanationProvider):
    def __init__(
        self, *, client: httpx.Client, base_url: str, model: str, timeout_seconds: float = 30
    ):
        self.client = client
        self.base_url = base_url.rstrip("/")
        self.model = model
        self.timeout_seconds = timeout_seconds

    @property
    def configured(self) -> bool:
        return True

    def _post(self, *, json: dict[str, object]) -> httpx.Response:
        state = shared_cooldown(
            hashlib.sha256(self.base_url.encode()).hexdigest(), "ollama:" + self.model
        )
        if state.reason():
            raise RuntimeError("ollama_temporarily_unavailable")
        try:
            response = self.client.post(
                f"{self.base_url}/api/chat", json=json, timeout=self.timeout_seconds
            )
            response.raise_for_status()
            return response
        except (httpx.HTTPStatusError, httpx.TransportError) as error:
            status = (
                error.response.status_code if isinstance(error, httpx.HTTPStatusError) else None
            )
            if status is None or status in {408, 429} or 500 <= status <= 599:
                delay = (
                    provider_retry_delay(error.response, 15)
                    if isinstance(error, httpx.HTTPStatusError)
                    else 15
                )
                state.block(delay, "ollama_unavailable")
                get_logger().warning(
                    "ai_local_unavailable",
                    model=self.model,
                    error_type=type(error).__name__,
                    upstream_status=status,
                )
            raise

    def generate_json(
        self, *, system_prompt: str, text: str, schema: dict[str, object], max_tokens: int = 2048
    ) -> str:
        response = self._post(
            json={
                "model": self.model,
                "stream": False,
                "format": schema,
                "think": False,
                "options": {
                    "temperature": 0,
                    "num_predict": min(max_tokens, 2048),
                    "num_ctx": 8192,
                },
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": text},
                ],
            },
        )
        response.raise_for_status()
        value = response.json()
        if value.get("done_reason") == "length":
            raise ValueError("ollama_incomplete_batch")
        content = value["message"]["content"]
        if not isinstance(content, str) or not content.strip():
            raise ValueError("ollama_empty_batch")
        return content

    def explain(self, *, system_prompt: str, context: str, question: str) -> GeneratedExplanation:
        schema = ExplanationPayload.model_json_schema()
        source_ids = re.findall(r"SOURCE_ID=([^;\s]+)", context)
        if source_ids:
            schema["properties"]["source_ids"]["items"]["enum"] = list(dict.fromkeys(source_ids))
        response = self._post(
            json={
                "model": self.model,
                "stream": False,
                "format": schema,
                "think": False,
                "options": {"temperature": 0, "num_predict": 768, "num_ctx": 8192},
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {
                        "role": "user",
                        "content": f"TRUSTED DATA:\n{context}\n\nQUESTION:\n{question}",
                    },
                ],
            },
        )
        response.raise_for_status()
        content = response.json()["message"]["content"]
        return replace(_parse_explanation(content), provider="ollama", model=self.model)


class GeminiProvider(AiExplanationProvider):
    """Server-side Gemini REST client; credentials never appear in request URLs."""

    def __init__(
        self, *, client: httpx.Client, model: str, api_key: str | None, timeout_seconds: float = 20
    ):
        self.client = client
        self.model = model
        self.api_key = api_key
        self.timeout_seconds = timeout_seconds
        self.cooldown_seconds: float = 300

    @property
    def configured(self) -> bool:
        return bool(self.api_key)

    def explain(self, *, system_prompt: str, context: str, question: str) -> GeneratedExplanation:
        schema = ExplanationPayload.model_json_schema()
        source_ids = re.findall(r"SOURCE_ID=([^;\s]+)", context)
        if source_ids:
            schema["properties"]["source_ids"]["items"]["enum"] = list(dict.fromkeys(source_ids))
        content = self.generate_json(
            system_prompt=system_prompt,
            text=f"TRUSTED DATA:\n{context}\n\nQUESTION:\n{question}",
            schema=schema,
        )
        return replace(_parse_explanation(content), provider="gemini", model=self.model)

    def generate_json_with_availability_fallback(
        self,
        *,
        fallback_model: str,
        recovery_model: str | None = None,
        system_prompt: str,
        text: str,
        schema: dict[str, object],
        max_tokens: int = 2048,
        image_bytes: bytes | None = None,
        image_mime_type: str = "image/jpeg",
        high_resolution: bool = False,
        additional_images: list[bytes] | None = None,
    ) -> str:
        """Try each eligible model once; share availability, never patient data.

        An unscoped quota is project-wide. Only an explicit model quota allows
        another Gemini model; Retry-After is stored without sleeping the request.
        """
        started = time.monotonic()
        budget = self.timeout_seconds
        models = list(dict.fromkeys(m for m in [self.model, fallback_model, recovery_model] if m))
        fingerprint = hashlib.sha256((self.api_key or "").encode()).hexdigest()
        project_state = shared_cooldown(fingerprint, "cloud:*")
        reason = project_state.reason()
        if reason:
            raise GeminiModelsUnavailable(reason)
        models = [m for m in models if scan_model_cooldown(fingerprint, m).reason() is None]
        if image_bytes:
            # Explicit, deployment-verified capabilities; never guess from a model name.
            models = [m for m in models if m in GEMINI_IMAGE_MODELS]
        if not models:
            reasons = [
                scan_model_cooldown(fingerprint, m).reason()
                for m in [self.model, fallback_model, recovery_model]
                if m
            ]
            raise GeminiModelsUnavailable(
                "gemini_quota_exhausted"
                if any(r and "quota" in r for r in reasons)
                else "gemini_unavailable"
            )
        last_error: httpx.HTTPError | None = None
        try:
            for attempt, model in enumerate(models):
                remaining = budget - (time.monotonic() - started)
                if remaining <= 0:
                    break
                self.model = model
                attempts_left = len(models) - attempt
                self.timeout_seconds = (
                    min(30, remaining * (0.4 if attempts_left > 2 else 0.6))
                    if attempts_left > 1
                    else remaining
                )
                attempt_started = time.monotonic()
                try:
                    result = self.generate_json(
                        system_prompt=system_prompt,
                        text=text,
                        schema=schema,
                        max_tokens=max_tokens,
                        image_bytes=image_bytes,
                        image_mime_type=image_mime_type,
                        additional_images=additional_images,
                        high_resolution=high_resolution,
                    )
                    get_logger().info(
                        "gemini_model_completed",
                        model=model,
                        attempt=attempt + 1,
                        elapsed_seconds=round(time.monotonic() - attempt_started, 2),
                    )
                    return result
                except (httpx.HTTPStatusError, httpx.TransportError) as error:
                    last_error = error
                    status = (
                        error.response.status_code
                        if isinstance(error, httpx.HTTPStatusError)
                        else None
                    )
                    if (
                        status is not None
                        and status not in {402, 404, 408, 429}
                        and not (500 <= status <= 599)
                    ):
                        raise  # Credentials, invalid input and safety blocks are not retried.
                    quota = status in {402, 429}
                    reason = "gemini_quota_exhausted" if quota else "gemini_unavailable"
                    delay = (
                        provider_retry_delay(error.response, self.cooldown_seconds)
                        if isinstance(error, httpx.HTTPStatusError)
                        else min(30, self.cooldown_seconds)
                    )
                    state = scan_model_cooldown(fingerprint, model)
                    state.block(delay, reason)
                    # Unknown quota scope is conservatively project-wide. A server's
                    # unscoped Retry-After also pauses all requests to that provider.
                    project_wide = quota and not model_scoped_quota(error, model)
                    if isinstance(error, httpx.HTTPStatusError) and not quota:
                        project_wide = bool(error.response.headers.get("retry-after"))
                    if project_wide:
                        project_state.block(delay, reason)
                    get_logger().warning(
                        "gemini_model_unavailable",
                        model=model,
                        attempt=attempt + 1,
                        upstream_status=status,
                        error_type=type(error).__name__,
                        cooldown_seconds=delay,
                        scope="project" if project_wide else "model",
                    )
                    if project_wide:
                        raise
            if last_error:
                raise last_error
            raise GeminiModelsUnavailable("gemini_unavailable")
        finally:
            self.timeout_seconds = budget

    def generate_json(
        self,
        *,
        system_prompt: str,
        text: str,
        schema: dict[str, object],
        max_tokens: int = 2048,
        image_bytes: bytes | None = None,
        image_mime_type: str = "image/jpeg",
        high_resolution: bool = False,
        additional_images: list[bytes] | None = None,
    ) -> str:
        if not self.configured:
            raise RuntimeError("gemini_not_configured")
        response = self.client.post(
            f"https://generativelanguage.googleapis.com/v1beta/models/{self.model}:generateContent",
            headers={"x-goog-api-key": self.api_key or ""},
            timeout=self.timeout_seconds,
            json={
                "systemInstruction": {"parts": [{"text": system_prompt}]},
                "contents": [
                    {
                        "role": "user",
                        "parts": (
                            [
                                {
                                    "inlineData": {
                                        "mimeType": image_mime_type,
                                        "data": base64.b64encode(pixels).decode("ascii"),
                                    }
                                }
                                for pixels in [image_bytes, *(additional_images or [])]
                            ]
                            if image_bytes
                            else []
                        )
                        + [{"text": text}],
                    }
                ],
                "generationConfig": {
                    "temperature": 0,
                    **(
                        {"mediaResolution": "MEDIA_RESOLUTION_HIGH"}
                        if image_bytes and high_resolution
                        else {}
                    ),
                    "maxOutputTokens": max_tokens,
                    "responseFormat": {"text": {"mimeType": "APPLICATION_JSON", "schema": schema}},
                },
            },
        )
        response.raise_for_status()
        payload = response.json()
        candidates = payload.get("candidates") or []
        if not candidates or candidates[0].get("finishReason") != "STOP":
            # Never turn blocked/truncated content into an apparent successful explanation.
            raise ValueError("gemini_blocked_or_incomplete")
        parts = candidates[0].get("content", {}).get("parts", [])
        return "".join(part.get("text", "") for part in parts if not part.get("thought"))


class ProviderCooldown:
    """Only provider availability is shared across requests, never questions or medical text."""

    def __init__(self, clock: Callable[[], float] = time.monotonic):
        self.clock = clock
        self._lock = threading.Lock()
        self._until = 0.0
        self._reason: str | None = None

    def reason(self) -> str | None:
        with self._lock:
            return self._reason if self.clock() < self._until else None

    def block(self, seconds: float, reason: str) -> None:
        with self._lock:
            self._until = max(self._until, self.clock() + max(1, min(seconds, 86400)))
            self._reason = reason


@lru_cache(maxsize=32)
def shared_cooldown(key_fingerprint: str, model: str) -> ProviderCooldown:
    return ProviderCooldown(clock=time.monotonic)


@lru_cache(maxsize=64)
def scan_model_cooldown(key_fingerprint: str, model: str) -> ProviderCooldown:
    """Shared per-model state across text, structuring and image workflows."""
    return shared_cooldown(key_fingerprint, "cloud:" + model)


# Google documents these as multimodal; both IDs were checked against this deployment.
GEMINI_IMAGE_MODELS = frozenset({"gemini-3.5-flash-lite", "gemini-3.1-flash-lite"})


class GeminiModelsUnavailable(AppException):
    def __init__(self, reason: str):
        super().__init__(
            "cloud_temporarily_unavailable",
            "AI models are temporarily unavailable.",
            status_code=503,
        )
        self.reason = reason


def model_scoped_quota(error: httpx.HTTPError, model: str) -> bool:
    """Fail closed for unknown/global/mixed quotas; never rotate keys or projects."""
    if not isinstance(error, httpx.HTTPStatusError):
        return False
    try:
        details = error.response.json().get("error", {}).get("details", [])
        violations = [
            v
            for d in details
            if str(d.get("@type", "")).endswith("QuotaFailure")
            for v in d.get("violations", [])
        ]
        return bool(violations) and all(
            v.get("quotaDimensions", {}).get("model") in {model, "models/" + model}
            and "permodel" in str(v.get("quotaId", "")).lower()
            for v in violations
        )
    except (ValueError, AttributeError, TypeError):
        return False


class GeminiOllamaProvider(AiExplanationProvider):
    def __init__(
        self,
        *,
        primary: GeminiProvider,
        fallback: OllamaProvider,
        cooldown: ProviderCooldown,
        cooldown_seconds: float = 300,
    ):
        self.primary = primary
        self.fallback = fallback
        self.cooldown = cooldown
        self.cooldown_seconds = cooldown_seconds

    @property
    def configured(self) -> bool:
        return self.primary.configured or self.fallback.configured

    def explain(self, *, system_prompt: str, context: str, question: str) -> GeneratedExplanation:
        manages_availability = getattr(self.primary, "manages_availability", False)
        reason = None if manages_availability else self.cooldown.reason()
        if not self.primary.configured:
            reason = "gemini_not_configured"
        if reason is None:
            try:
                return self.primary.explain(
                    system_prompt=system_prompt, context=context, question=question
                )
            except httpx.HTTPStatusError as error:
                status = error.response.status_code
                recoverable = (
                    status in {402, 429, 408}
                    or 500 <= status <= 599
                    or (manages_availability and status == 404)
                )
                if not recoverable:
                    raise  # Invalid keys/input and safety blocks are not quota exhaustion.
                reason = "gemini_quota_exhausted" if status in {402, 429} else "gemini_unavailable"
                self.cooldown.block(self._retry_after(error.response), reason)
            except AppException as error:
                if error.code not in {"cloud_limit_reached", "cloud_temporarily_unavailable"}:
                    raise
                reason = (
                    "cloud_quota_exhausted"
                    if error.code == "cloud_limit_reached"
                    else "cloud_unavailable"
                )
                if not manages_availability:
                    self.cooldown.block(min(30, self.cooldown_seconds), reason)
            except httpx.TransportError:
                reason = "gemini_unavailable"
                self.cooldown.block(min(30, self.cooldown_seconds), reason)
        generated = self.fallback.explain(
            system_prompt=system_prompt, context=context, question=question
        )
        return replace(
            generated, provider="ollama", model=self.fallback.model, fallback_reason=reason
        )

    def _retry_after(self, response: httpx.Response) -> float:
        return provider_retry_delay(response, self.cooldown_seconds)


def provider_retry_delay(response: httpx.Response, default_seconds: float) -> float:
    value = response.headers.get("retry-after")
    if value:
        try:
            return max(1, min(float(value), 86400))
        except ValueError:
            try:
                return max(
                    1,
                    min(
                        (parsedate_to_datetime(value) - datetime.now(UTC)).total_seconds(),
                        86400,
                    ),
                )
            except (ValueError, TypeError, OverflowError):
                pass
    try:
        for detail in response.json().get("error", {}).get("details", []):
            if str(detail.get("@type", "")).endswith("google.rpc.RetryInfo"):
                return max(1, min(float(detail["retryDelay"].removesuffix("s")), 86400))
    except (ValueError, KeyError, TypeError, AttributeError):
        pass
    return default_seconds
