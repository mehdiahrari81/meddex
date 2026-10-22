import httpx

from app.services.medication_intelligence import MedicationIntelligenceService
from app.services.medicine_name_resolution import MedicineNameResolver


def make_resolver(client, names, concepts, related=None, compounds=None):
    calls = []

    def respond(request):
        calls.append(request)
        path = request.url.path
        if request.url.host == "pubchem.ncbi.nlm.nih.gov":
            assert request.url.params["name_type"] == "complete"
            value = (compounds or {}).get(path.split("/name/")[1].split("/property/")[0])
            return (
                httpx.Response(200, json={"PropertyTable": {"Properties": value}})
                if value
                else httpx.Response(404, json={})
            )
        if path.endswith("/rxcui.json"):
            assert request.url.params["search"] == "2"
            return httpx.Response(
                200, json={"idGroup": {"rxnormId": names.get(request.url.params["name"], [])}}
            )
        identifier = path.split("/rxcui/")[1].split("/")[0]
        if path.endswith("/properties.json"):
            return httpx.Response(200, json={"properties": concepts.get(identifier, {})})
        if path.endswith("/related.json"):
            return httpx.Response(
                200, json={"relatedGroup": {"conceptGroup": (related or {}).get(identifier, [])}}
            )
        raise AssertionError(path)

    http = httpx.Client(transport=httpx.MockTransport(respond))
    db = client.app.state.session_factory()
    service = MedicationIntelligenceService(db, client.app.state.settings, client=http)
    return MedicineNameResolver(service), calls, db, http


def concept(identifier, name, kind="IN"):
    return {"rxcui": identifier, "name": name, "tty": kind}


def group(kind, *values):
    return {"tty": kind, "conceptProperties": list(values)}


def test_generic_name_uses_ingredient_itself_and_caches_public_lookup(client):
    resolver, calls, db, http = make_resolver(
        client, {"metformin": ["6809"]}, {"6809": concept("6809", "metformin")}
    )
    try:
        first = resolver.resolve("metformin")
        assert first.relationship == "generic"
        assert first.candidate.strength is None
        count = len(calls)
        again = resolver.resolve("metformin")
        assert again.candidate.candidate_id == first.candidate.candidate_id
        assert len(calls) == count
        assert not any("/related.json" in str(c.url) for c in calls)
    finally:
        db.close()
        http.close()


def test_brand_resolves_active_ingredient_without_choosing_a_strength(client):
    resolver, _, db, http = make_resolver(
        client,
        {"Lipitor": ["153165"]},
        {"153165": concept("153165", "Lipitor", "BN")},
        {"153165": [group("IN", concept("83367", "atorvastatin"))]},
    )
    try:
        result = resolver.resolve("Lipitor")
        assert result.relationship == "brand"
        assert result.candidate.canonical_name == "atorvastatin"
        assert result.candidate.strength is None and result.candidate.dosage_form is None
    finally:
        db.close()
        http.close()


def test_generic_synonym_is_not_treated_as_a_different_medicine(client):
    resolver, _, db, http = make_resolver(
        client, {"paracetamol": ["161"]}, {"161": concept("161", "acetaminophen")}
    )
    try:
        result = resolver.resolve("paracetamol")
        assert result.relationship == "synonym"
        assert result.candidate.canonical_name == "acetaminophen"
    finally:
        db.close()
        http.close()


def test_combination_brand_keeps_all_active_ingredients(client):
    resolver, _, db, http = make_resolver(
        client,
        {"Augmentin": ["151392"]},
        {"151392": concept("151392", "Augmentin", "BN")},
        {
            "151392": [
                group("IN", concept("723", "amoxicillin"), concept("48203", "clavulanate")),
                group("MIN", concept("19711", "amoxicillin / clavulanate", "MIN")),
            ]
        },
    )
    try:
        result = resolver.resolve("Augmentin")
        assert result.candidate.canonical_name == "amoxicillin / clavulanate"
        assert {i.name for i in result.candidate.ingredients} == {"amoxicillin", "clavulanate"}
    finally:
        db.close()
        http.close()


def test_international_alias_requires_exact_pubchem_and_rxnorm_identity(client):
    resolver, calls, db, http = make_resolver(
        client,
        {"Concor": [], "Bisoprolol Fumarate": ["19484"]},
        {"19484": concept("19484", "bisoprolol fumarate", "PIN")},
        {"19484": [group("IN", concept("19483", "bisoprolol"))]},
        {"Concor": [{"CID": 5281064, "Title": "Bisoprolol Fumarate"}]},
    )
    try:
        result = resolver.resolve("Concor")
        assert result.candidate.canonical_name == "bisoprolol"
        assert result.sources[0].provider == "pubchem"
        assert result.sources[1].provider == "rxnorm"
        assert not any("approximate" in str(c.url) for c in calls)
    finally:
        db.close()
        http.close()


def test_conflicting_exact_matches_are_not_resolved_by_cherry_picking(client):
    resolver, calls, db, http = make_resolver(
        client,
        {"unclear": ["1", "2"]},
        {"1": concept("1", "first drug"), "2": concept("2", "different drug")},
    )
    try:
        assert resolver.resolve("unclear") is None
        assert not any(c.url.host == "pubchem.ncbi.nlm.nih.gov" for c in calls)
    finally:
        db.close()
        http.close()


def test_multiple_pubchem_compounds_are_not_silently_collapsed(client):
    resolver, _, db, http = make_resolver(
        client,
        {},
        {},
        compounds={"unclear": [{"CID": 1, "Title": "first"}, {"CID": 2, "Title": "second"}]},
    )
    try:
        assert resolver.resolve("unclear") is None
    finally:
        db.close()
        http.close()


def test_missing_name_reference_expires_quickly_and_is_retried(client):
    from datetime import timedelta

    from app.core.time import utc_now
    from app.models import ProviderCacheEntry
    from app.services.provider_cache import ProviderCache

    names = {}
    concepts = {}
    resolver, _, db, http = make_resolver(client, names, concepts)
    try:
        assert resolver.resolve("recoverable") is None
        key = ProviderCache.key(
            "nlm_medicine_names", "general_information_identity", {"name": "recoverable"}
        )
        entry = db.get(ProviderCacheEntry, key)
        assert ProviderCache._aware(entry.expires_at) < utc_now() + timedelta(minutes=3)
        names["recoverable"] = ["6809"]
        concepts["6809"] = concept("6809", "metformin")
        entry.expires_at = utc_now() - timedelta(seconds=1)
        db.commit()
        assert resolver.resolve("recoverable").candidate.canonical_name == "metformin"
    finally:
        db.close()
        http.close()


def test_failed_refresh_of_a_negative_result_is_service_failure_not_unknown_medicine(client):
    from datetime import timedelta

    import pytest

    from app.core.time import utc_now
    from app.models import ProviderCacheEntry
    from app.services.provider_cache import ProviderCache

    resolver, _, db, http = make_resolver(client, {}, {})
    try:
        assert resolver.resolve("recoverable") is None
        key = ProviderCache.key(
            "nlm_medicine_names", "general_information_identity", {"name": "recoverable"}
        )
        db.get(ProviderCacheEntry, key).expires_at = utc_now() - timedelta(seconds=1)
        db.commit()
        http.close()
        with pytest.raises(httpx.RequestError, match="medicine_reference_temporarily_unavailable"):
            # Use a transport failure rather than a successful no-match response.
            resolver._payload = lambda _: (_ for _ in ()).throw(httpx.RequestError("offline"))
            resolver.resolve("recoverable")
    finally:
        db.close()
        http.close()
