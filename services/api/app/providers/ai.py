import re
from abc import ABC, abstractmethod
from dataclasses import dataclass

import httpx
from pydantic import BaseModel, ConfigDict, Field, field_validator


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
        return _parse_explanation(content)


class OllamaProvider(AiExplanationProvider):
    def __init__(self, *, client: httpx.Client, base_url: str, model: str):
        self.client = client
        self.base_url = base_url.rstrip("/")
        self.model = model

    @property
    def configured(self) -> bool:
        return True

    def explain(self, *, system_prompt: str, context: str, question: str) -> GeneratedExplanation:
        schema = ExplanationPayload.model_json_schema()
        source_ids = re.findall(r"SOURCE_ID=([^;\s]+)", context)
        if source_ids:
            schema["properties"]["source_ids"]["items"]["enum"] = list(dict.fromkeys(source_ids))
        response = self.client.post(
            f"{self.base_url}/api/chat",
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
        return _parse_explanation(content)
