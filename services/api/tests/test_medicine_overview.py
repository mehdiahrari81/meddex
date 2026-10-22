from sqlalchemy import select

from app.models import MedicalFact, MedicationIdentity, MedicationResolution
from app.providers.ai import GeneratedExplanation
from app.schemas.intelligence import MedicationCandidateRead
from app.services.medical_rag import MedicalRagService
from app.services.medication_intelligence import MedicationIntelligenceService
from app.services.medicine_overview import MedicineOverviewRequest, select_reference
from tests.conftest import auth_headers
from tests.test_intelligence import _grounded_medication


def candidate(name="atorvastatin 10 MG Oral Tablet [Lipitor]", **values):
    return MedicationCandidateRead(
        candidate_id=values.pop("candidate_id", "rxnorm:617314"),
        canonical_name=name,
        brand_name="Lipitor",
        generic_name="atorvastatin",
        strength="10 MG",
        dosage_form="oral tablet",
        provider="rxnorm",
        provider_version="fixture",
        match_score=0.9,
        exact_identity=True,
        **values,
    )


def test_preview_requires_exact_name_strength_and_form_without_fuzzy_correction():
    request = MedicineOverviewRequest(name="Lipitor", strength="10mg", dosage_form="Tabs")
    match = candidate()
    assert select_reference(request, [match]) == match
    assert select_reference(request.model_copy(update={"name": "Lipit0r"}), [match]) is None
    assert select_reference(request.model_copy(update={"strength": "20 mg"}), [match]) is None
    assert select_reference(request.model_copy(update={"dosage_form": "Capsule"}), [match]) is None
    assert (
        select_reference(request, [match, match.model_copy(update={"candidate_id": "other"})])
        == match
    )


def test_distinct_products_are_not_arbitrarily_selected():
    request = MedicineOverviewRequest(name="Lipitor")
    assert (
        select_reference(
            request, [candidate(), candidate("atorvastatin 20 MG Oral Tablet [Lipitor]")]
        )
        is None
    )


def test_overview_requires_authentication_and_rejects_empty_name(client, registered):
    path = "/api/v1/prescription-ocr/medicine-overview"
    assert client.post(path, json={"name": "Lipitor"}).status_code == 401
    assert (
        client.post(
            path, headers=auth_headers(registered["access_token"]), json={"name": "  "}
        ).status_code
        == 422
    )


def test_general_preview_does_not_confirm_a_patient_resolution(client, registered, monkeypatch):
    medicine = _grounded_medication(client)
    with client.app.state.session_factory() as db:
        fact = db.scalar(select(MedicalFact).where(MedicalFact.medication_id == medicine.id))
        fact.fact_type = "patient_information"
        db.commit()
    match = candidate("Source medicine")
    monkeypatch.setattr(MedicationIntelligenceService, "_run_search", lambda *a, **k: [match])
    monkeypatch.setattr(MedicationIntelligenceService, "reference_identity", lambda *a: medicine)
    monkeypatch.setattr(MedicationIntelligenceService, "refresh_facts", lambda *a: "current")
    result = client.post(
        "/api/v1/prescription-ocr/medicine-overview",
        headers=auth_headers(registered["access_token"]),
        json={"name": "Source medicine"},
    )
    assert result.status_code == 200
    assert result.headers["cache-control"] == "no-store"
    assert result.json()["status"] == "available"
    assert result.json()["prescription_confirmed"] is False
    assert result.json()["explanation"]["source_references"]
    with client.app.state.session_factory() as db:
        assert db.scalars(select(MedicationResolution)).all() == []


def test_shared_ingredient_reference_is_not_rejected_as_an_unrelated_medicine(client, registered):
    reference = _grounded_medication(client)
    with client.app.state.session_factory() as db:
        db.add(
            MedicationIdentity(
                canonical_display_name="source ingredient",
                normalized_name="source ingredient",
                generic_name="source ingredient",
                brand_names=[],
                verification_state="external_identity_verified",
            )
        )
        db.commit()
        service = MedicalRagService(db, client.app.state.settings)
        medicine = db.get(MedicationIdentity, reference.id)
        fact = medicine.facts[0]
        assert service._grounded(
            GeneratedExplanation(
                answer="Source ingredient: read the official patient information.",
                mentioned_medications=("source ingredient",),
                source_ids=(str(fact.id),),
            ),
            medicine,
            [fact],
        )
        service.client.close()


def test_verified_betaloc_brand_is_ingredient_information_not_a_confirmed_us_product(
    client, registered, monkeypatch
):
    from app.models import MedicationProviderMapping
    from app.services.medicine_brand_reference import lookup_brand

    assert lookup_brand("Betaloc")[0].ingredient == "metoprolol"
    assert lookup_brand("Betaloq") is None  # No fuzzy brand substitution.
    reference = _grounded_medication(client)
    with client.app.state.session_factory() as db:
        fact = db.scalar(select(MedicalFact).where(MedicalFact.medication_id == reference.id))
        fact.fact_type = "patient_information"
        db.commit()
    monkeypatch.setattr(
        MedicationIntelligenceService,
        "_run_search",
        lambda *a: [],
    )
    from app.providers.medication import Ingredient, ProviderCandidate, RxNormProvider

    monkeypatch.setattr(
        RxNormProvider,
        "ingredient",
        lambda *a: ProviderCandidate(
            external_id="6918",
            canonical_name="metoprolol",
            generic_name="metoprolol",
            provider="rxnorm",
            provider_version="fixture",
            ingredients=(Ingredient(name="metoprolol"),),
            identifiers=({"type": "rxcui", "value": "6918", "jurisdiction": "US"},),
        ),
    )
    monkeypatch.setattr(MedicationIntelligenceService, "reference_identity", lambda *a: reference)
    monkeypatch.setattr(MedicationIntelligenceService, "refresh_facts", lambda *a: "current")
    response = client.post(
        "/api/v1/prescription-ocr/medicine-overview",
        headers=auth_headers(registered["access_token"]),
        json={"name": "Betaloc", "strength": "50 mg", "dosage_form": "Tablet"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "available"
    assert data["reference_scope"] == "ingredient"
    assert data["prescription_confirmed"] is False
    assert data["identity_sources"][0]["jurisdiction"] == "GB"
    assert "not confirmed" in data["reference_note"]
    with client.app.state.session_factory() as db:
        assert db.scalars(select(MedicationResolution)).all() == []
        mappings = db.scalars(
            select(MedicationProviderMapping).where(
                MedicationProviderMapping.provider == "verified_brand_reference"
            )
        ).all()
        assert len(mappings) == 1


def test_multiple_products_get_an_automatic_ingredient_explanation(client, registered, monkeypatch):
    from app.schemas.intelligence import IngredientRead
    from app.services.medicine_name_resolution import MedicineNameResolver, NameReference

    medicine = _grounded_medication(client)
    with client.app.state.session_factory() as db:
        fact = db.scalar(select(MedicalFact).where(MedicalFact.medication_id == medicine.id))
        fact.fact_type = "patient_information"
        db.commit()
    products = [candidate(), candidate("atorvastatin 20 MG Oral Tablet [Lipitor]")]
    monkeypatch.setattr(MedicationIntelligenceService, "_run_search", lambda *a, **k: products)
    ingredient = candidate().model_copy(
        update={
            "canonical_name": "atorvastatin",
            "brand_name": None,
            "strength": None,
            "dosage_form": None,
            "ingredients": [IngredientRead(name="atorvastatin")],
        }
    )
    monkeypatch.setattr(
        MedicineNameResolver,
        "resolve",
        lambda *a: NameReference(candidate=ingredient, relationship="brand"),
    )
    monkeypatch.setattr(MedicationIntelligenceService, "reference_identity", lambda *a: medicine)
    monkeypatch.setattr(MedicationIntelligenceService, "refresh_facts", lambda *a: "current")
    result = client.post(
        "/api/v1/prescription-ocr/medicine-overview",
        headers=auth_headers(registered["access_token"]),
        json={"name": "Lipitor"},
    )
    assert result.status_code == 200
    data = result.json()
    assert data["status"] == "available"
    assert data["reference_scope"] == "ingredient"
    assert data["name_relationship"] == "brand"
    assert data["explanation"]["answer"]
    assert data["prescription_confirmed"] is False
    with client.app.state.session_factory() as db:
        assert db.scalars(select(MedicationResolution)).all() == []


def test_bare_name_concepts_are_resolved_as_ingredients_instead_of_product_matches():
    bare = candidate().model_copy(update={"strength": None, "dosage_form": None})
    assert select_reference(MedicineOverviewRequest(name="Lipitor"), [bare]) is None
