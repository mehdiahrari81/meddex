from datetime import timedelta

from fastapi.testclient import TestClient

from app.core.time import utc_now
from app.services.provider_cache import ProviderCache


def test_cache_serializes_provider_dates_and_returns_consistent_payload(client: TestClient) -> None:
    timestamp = utc_now()
    with client.app.state.session_factory() as db:
        cache = ProviderCache(db)
        loaded = cache.get_or_refresh(
            provider="test",
            provider_version="v1",
            operation="facts",
            arguments={"id": "example"},
            ttl=timedelta(hours=1),
            loader=lambda: {"retrieved_at": timestamp},
        )
        db.expire_all()

        def unexpected_loader() -> dict[str, object]:
            raise AssertionError("A fresh cache entry must not load the provider again")

        cached = cache.get_or_refresh(
            provider="test",
            provider_version="v1",
            operation="facts",
            arguments={"id": "example"},
            ttl=timedelta(hours=1),
            loader=unexpected_loader,
        )
        assert loaded.payload == cached.payload == {"retrieved_at": timestamp.isoformat()}
        assert cached.state == "current"


def test_adapter_upgrade_refreshes_even_an_unexpired_result(client: TestClient) -> None:
    with client.app.state.session_factory() as db:
        cache = ProviderCache(db)
        arguments = dict(
            provider="test",
            operation="search",
            arguments={"query": "full name"},
            ttl=timedelta(days=1),
        )
        cache.get_or_refresh(**arguments, provider_version="v1", loader=lambda: {"candidates": []})
        updated = cache.get_or_refresh(
            **arguments, provider_version="v2", loader=lambda: {"candidates": ["exact-result"]}
        )
        assert updated.payload == {"candidates": ["exact-result"]}
        assert updated.provider_version == "v2"
