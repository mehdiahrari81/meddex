import argparse
import json
from dataclasses import asdict
from pathlib import Path

from app.core.config import get_settings
from app.db.session import create_database_engine, create_session_factory
from app.services.content_import import ContentImporter, DatasetValidationError

DEFAULT_DATASET = (
    Path(__file__).resolve().parents[3]
    / "apps"
    / "mobile"
    / "assets"
    / "terminology"
    / "starter_dataset_v1.json"
)


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate and import MediExplain content")
    parser.add_argument("path", nargs="?", type=Path, default=DEFAULT_DATASET)
    parser.add_argument("--dry-run", action="store_true")
    arguments = parser.parse_args()
    settings = get_settings()
    engine = create_database_engine(settings)
    factory = create_session_factory(engine)
    try:
        with factory() as db:
            importer = ContentImporter(db)
            report = importer.import_path(arguments.path, dry_run=True)
            if settings.environment == "production" and not report.production_approved:
                raise DatasetValidationError(
                    "Development-only content cannot be imported in production"
                )
            if not arguments.dry_run:
                report = importer.import_path(arguments.path)
        print(json.dumps(asdict(report), indent=2))
    except DatasetValidationError as error:
        print(json.dumps({"valid": False, "error": str(error)}, indent=2))
        return 2
    finally:
        engine.dispose()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
