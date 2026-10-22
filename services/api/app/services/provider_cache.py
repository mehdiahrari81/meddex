import hashlib
import json
from collections.abc import Callable
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

from sqlalchemy.orm import Session

from app.core.time import utc_now
from app.models import ProviderCacheEntry


@dataclass(frozen=True)
class CachedValue:
    payload: dict[str, object]
    state: str
    provider_version: str


class ProviderCache:
    def __init__(self, db: Session):
        self.db = db

    def get_or_refresh(
        self,
        *,
        provider: str,
        provider_version: str,
        operation: str,
        arguments: dict[str, str],
        ttl: timedelta | Callable[[dict[str, object]], timedelta],
        loader: Callable[[], dict[str, object]],
    ) -> CachedValue:
        cache_key = self.key(provider, operation, arguments)
        existing = self.db.get(ProviderCacheEntry, cache_key)
        now = utc_now()
        if (
            existing is not None
            and existing.provider_version == provider_version
            and self._aware(existing.expires_at) >= now
        ):
            return CachedValue(existing.payload, "current", existing.provider_version)
        try:
            payload = loader()
        except Exception:
            if existing is not None:
                existing.last_refresh_attempt_at = now
                existing.refresh_error_code = "provider_refresh_failed"
                self.db.commit()
                return CachedValue(existing.payload, "stale", existing.provider_version)
            raise

        def default_encoder(obj: object) -> str:
            if isinstance(obj, datetime):
                return obj.isoformat()
            raise TypeError(f"Object of type {obj.__class__.__name__} is not JSON serializable")

        serialized = json.dumps(
            payload, sort_keys=True, separators=(",", ":"), default=default_encoder
        )
        # Persist exactly the canonical JSON representation, including ISO dates.
        # Returning that same shape makes cache misses and hits consistent.
        payload = json.loads(serialized)
        content_hash = hashlib.sha256(serialized.encode()).hexdigest()
        if existing is None:
            existing = ProviderCacheEntry(cache_key=cache_key, provider=provider)
            self.db.add(existing)
        existing.provider_version = provider_version
        existing.payload = payload
        existing.content_hash = content_hash
        existing.fetched_at = now
        existing.expires_at = now + (ttl(payload) if callable(ttl) else ttl)
        existing.last_refresh_attempt_at = now
        existing.refresh_error_code = None
        self.db.commit()
        return CachedValue(payload, "current", provider_version)

    @staticmethod
    def key(provider: str, operation: str, arguments: dict[str, str]) -> str:
        material = json.dumps(
            {"provider": provider, "operation": operation, "arguments": arguments},
            sort_keys=True,
            separators=(",", ":"),
        )
        return hashlib.sha256(material.encode()).hexdigest()

    @staticmethod
    def _aware(value: datetime) -> datetime:
        # SQLite drops timezone metadata; production PostgreSQL preserves it.
        return value if value.tzinfo is not None else value.replace(tzinfo=UTC)
