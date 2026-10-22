import httpx
import pytest

from app.providers.medication import RxNormProvider
from app.services.medicine_brand_reference import lookup_brand


@pytest.mark.parametrize(
    "brand, ingredient, kind",
    [
        ("MEFTAL-P", "mefenamic acid", "PIN"),
        ("DELCON", "chlorpheniramine / phenylephrine", "MIN"),
        ("CALPOL", "acetaminophen", "IN"),
        ("LEVOLIN", "levalbuterol", "IN"),
    ],
)
def test_verified_brand_ingredients_accept_precise_and_combination_concepts(
    brand, ingredient, kind
):
    record, _ = lookup_brand(brand)
    assert record.ingredient == ingredient

    def respond(request):
        assert request.url.path.endswith(f"/{record.rxcui}/properties.json")
        return httpx.Response(
            200, json={"properties": {"rxcui": record.rxcui, "name": ingredient, "tty": kind}}
        )

    with httpx.Client(transport=httpx.MockTransport(respond)) as http:
        candidate = RxNormProvider(http).ingredient(record.rxcui, record.ingredient)
    assert candidate.canonical_name == ingredient
    assert {x.name for x in candidate.ingredients} == set(ingredient.split(" / "))
    assert candidate.strength is None and candidate.dosage_form is None
    assert candidate.metadata["term_type"] == kind


def test_brand_variants_and_spelling_errors_are_not_automatically_substituted():
    assert lookup_brand("DELCON PLUS") is None
    assert lookup_brand("DELCON LS") is None
    assert lookup_brand("MEFTAL-SPAS") is None
    assert lookup_brand("Oxprelol") is None


def test_curated_ingredient_lookup_rejects_product_concepts_and_wrong_names():
    def respond(request):
        return httpx.Response(
            200, json={"properties": {"rxcui": "123", "name": "different drug", "tty": "SCD"}}
        )

    with httpx.Client(transport=httpx.MockTransport(respond)) as http:
        assert RxNormProvider(http).ingredient("123", "different drug") is None
        assert RxNormProvider(http).ingredient("123", "mefenamic acid") is None
