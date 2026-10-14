from unittest.mock import Mock

from fastapi.testclient import TestClient
from sqlalchemy import select

from app.models import MedicationIdentity, MedicationIngredient, MedicationProviderMapping
from app.providers.medication import Ingredient, ProviderCandidate
from app.services.rxnorm_mapper import RxNormMapper


def test_mapping_rejects_search_ranking_missing_strength_and_ambiguity(client: TestClient) -> None:
    with client.app.state.session_factory() as db:
        identity = MedicationIdentity(
            canonical_display_name="Local tablet",
            normalized_name="local tablet",
            generic_name="Ingredient",
            brand_names=["Local tablet"],
            dosage_form="tablet",
            country="PK",
            verification_state="local_registry_match",
            ingredients=[
                MedicationIngredient(
                    name="Ingredient",
                    normalized_name="ingredient",
                    numerator_value="10",
                    numerator_unit="mg",
                    position=0,
                )
            ],
        )
        db.add(identity)
        db.commit()
        provider = Mock()
        mapper = RxNormMapper(db, provider)
        incomplete = ProviderCandidate(
            "1",
            "Ingredient",
            "rxnorm",
            "test",
            dosage_form="tablet",
            ingredients=(Ingredient("Ingredient"),),
        )
        provider.search.return_value = [incomplete]
        assert mapper.map_drap_to_rxnorm() == 0
        exact = ProviderCandidate(
            "2",
            "Ingredient 10 mg",
            "rxnorm",
            "test",
            dosage_form="tablet",
            ingredients=(Ingredient("Ingredient", "10", "mg"),),
        )
        other = ProviderCandidate(
            "3",
            "Ingredient 10 mg",
            "rxnorm",
            "test",
            dosage_form="tablet",
            ingredients=exact.ingredients,
        )
        provider.search.return_value = [exact, other]
        assert mapper.map_drap_to_rxnorm() == 0
        provider.search.return_value = [exact]
        assert mapper.map_drap_to_rxnorm() == 1
        assert db.scalar(select(MedicationProviderMapping)).external_id == "2"
