"""Isolated API fixture for real-browser tests; never uses a configured database."""

import json
import os
from pathlib import Path
from tempfile import TemporaryDirectory

import uvicorn
from alembic.config import Config
from sqlalchemy.orm import Session

from alembic import command
from app.cli import provision_admin
from app.core.config import Settings, get_settings
from app.db.session import create_database_engine
from app.factory import create_app
from app.services.content_import import ContentImporter
from app.services.demo_data import seed_demo_data


def main() -> None:
    with TemporaryDirectory(prefix="mediexplain-browser-") as temporary:
        os.environ["MEDIEXPLAIN_ENVIRONMENT"] = "testing"
        os.environ["MEDIEXPLAIN_DATABASE_URL"] = f"sqlite+pysqlite:///{temporary}/browser.db"
        get_settings.cache_clear()
        settings = Settings(
            environment="testing",
            database_url=os.environ["MEDIEXPLAIN_DATABASE_URL"],
            secret_key="isolated-browser-test-key-never-use-in-production",
            rate_limit_per_minute=10_000,
            admin_mfa_required=False,
            rxnorm_enabled=False,
            medlineplus_enabled=False,
            dailymed_enabled=False,
        )
        command.upgrade(Config("alembic.ini"), "head")
        engine = create_database_engine(settings)
        with Session(engine) as db:
            ContentImporter(db).import_path(
                Path(__file__).resolve().parents[3]
                / "apps/mobile/assets/terminology/starter_dataset_v1.json"
            )
            for email, role in (
                ("admin@example.com", "SUPER_ADMIN"),
                ("editor@example.com", "CONTENT_EDITOR"),
                ("reviewer@example.com", "CONTENT_REVIEWER"),
                ("support@example.com", "SUPPORT_READ_ONLY"),
            ):
                provision_admin(
                    db,
                    settings,
                    email=email,
                    password="BrowserTest!1234",
                    display_name="Browser Test",
                    role_name=role,
                )
            dataset_path = (
                Path(__file__).resolve().parents[3]
                / "apps/mobile/assets/terminology/starter_dataset_v1.json"
            )
            seed_demo_data(db, settings, "admin@example.com", json.loads(dataset_path.read_text()))
        try:
            uvicorn.run(
                create_app(settings, engine=engine),
                host="127.0.0.1",
                port=18080,
                log_level="warning",
            )
        finally:
            engine.dispose()


if __name__ == "__main__":
    main()
