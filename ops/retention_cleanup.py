"""Idempotent retention cleanup. Run under a scheduler with API environment set."""

from datetime import timedelta

from sqlalchemy import delete

from app.core.config import get_settings
from app.core.time import utc_now
from app.db.session import create_database_engine, create_session_factory
from app.models import AiConversation, ProviderCacheEntry


def main() -> None:
    settings = get_settings()
    factory = create_session_factory(create_database_engine(settings))
    now = utc_now()
    with factory.begin() as db:
        conversations = db.execute(
            delete(AiConversation).where(AiConversation.expires_at < now)
        ).rowcount
        cache = db.execute(
            delete(ProviderCacheEntry).where(
                ProviderCacheEntry.expires_at
                < now - timedelta(days=settings.provider_cache_retention_days)
            )
        ).rowcount
    print({"expired_ai_conversations": conversations, "expired_provider_cache": cache})


if __name__ == "__main__":
    main()
