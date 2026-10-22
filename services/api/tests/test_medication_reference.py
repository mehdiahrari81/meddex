import json
from pathlib import Path
from uuid import UUID

import httpx
from fastapi.testclient import TestClient
from sqlalchemy import func, select

from app.core.config import Settings
from app.models import MedicationIdentity
from app.providers.medication import RxNormReferenceProvider
from app.services.medication_intelligence import MedicationIntelligenceService
from app.services.medication_reference import import_medication_reference

SNAPSHOT = Path(__file__).resolve().parents[3] / "data" / "rxnorm_reference.json"


def test_reference_import_is_repeatable_and_searchable(client: TestClient) -> None:
    expected = len(json.loads(SNAPSHOT.read_text())["records"])
    with client.app.state.session_factory() as db:
        first = import_medication_reference(db, SNAPSHOT)
        assert first["added"] == expected
        assert import_medication_reference(db, SNAPSHOT) == {"added": 0, "preserved": expected}
        assert db.scalar(select(func.count()).select_from(MedicationIdentity)) == expected
        provider = RxNormReferenceProvider(db)
        results = provider.search("acetaminophen", country="US")
        assert results
        assert all(item.country == "US" and item.provider == "rxnorm" for item in results)
        assert provider.search("acetaminophen", country="PK") == []


def test_reference_resolution_survives_upstream_outage(
    client: TestClient, registered: dict[str, str]
) -> None:
    def offline(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("offline", request=request)

    with client.app.state.session_factory() as db:
        import_medication_reference(db, SNAPSHOT)
        service = MedicationIntelligenceService(
            db, Settings(), client=httpx.Client(transport=httpx.MockTransport(offline))
        )
        result = service.create_resolution(
            user_id=UUID(registered["user_id"]),
            raw_value="acetaminophen",
            input_origin="manual",
            strength=None,
            dosage_form=None,
            country="US",
            prescription_item_id=None,
        )
        assert result.candidates
        assert result.selected_candidate_id is None
        assert result.medication_id is None
        assert result.provider_failures
