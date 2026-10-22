"""Resolve a written name to an ingredient reference, never to a patient's dose/product."""

from datetime import timedelta
from typing import Literal
from urllib.parse import quote
from uuid import NAMESPACE_URL, uuid5

import httpx
from pydantic import Field

from app.core.time import utc_now
from app.providers.medication import Ingredient, ProviderCandidate, normalize_search
from app.schemas.common import StrictSchema
from app.schemas.intelligence import MedicationCandidateRead, SourceReferenceRead
from app.services.medication_intelligence import MedicationIntelligenceService


class NameReference(StrictSchema):
    candidate: MedicationCandidateRead
    relationship: Literal["brand", "generic", "synonym", "product"]
    sources: list[SourceReferenceRead] = Field(default_factory=list)


class AmbiguousMedicineName(ValueError):
    pass


def citation(provider: str, title: str, url: str) -> SourceReferenceRead:
    return SourceReferenceRead(
        id=str(uuid5(NAMESPACE_URL, url)),
        provider=provider,
        title=title,
        section="Medicine name and active ingredient identity",
        jurisdiction="US",
        language="en",
        content_version="ingredient-name-v2",
        retrieved_at=utc_now(),
        url=url,
    )


class MedicineNameResolver:
    def __init__(self, service: MedicationIntelligenceService):
        self.service = service
        self.rxnorm = service.rxnorm

    def resolve(self, name: str) -> NameReference | None:
        if not self.service._provider_enabled(
            "rxnorm_provider", self.service.settings.rxnorm_enabled
        ):
            return None
        cached = self.service.cache.get_or_refresh(
            provider="nlm_medicine_names",
            provider_version="normalized-ingredient-v3",
            operation="general_information_identity",
            arguments={"name": normalize_search(name)},
            ttl=lambda payload: (
                timedelta(days=7) if payload.get("reference") else timedelta(minutes=2)
            ),
            loader=lambda: self._payload(name),
        )
        value = cached.payload.get("reference")
        if not value and cached.state == "stale":
            # A failed refresh is not evidence that the medicine does not exist.
            raise httpx.RequestError("medicine_reference_temporarily_unavailable")
        return NameReference.model_validate(value) if value else None

    def _payload(self, name: str) -> dict[str, object]:
        try:
            result = self._rxnorm_name(name)
            if result is None:
                result = self._pubchem_name(name)
        except AmbiguousMedicineName:
            return {"reference": None, "ambiguous": True}
        return {"reference": result.model_dump(mode="json") if result else None}

    def _rxnorm_name(self, name: str) -> NameReference | None:
        # NLM normalization expands established abbreviations and salt/form variants.
        # It is used only for general ingredient information, never OCR correction,
        # product confirmation or dose selection. Approximate search is not used.
        data = self.rxnorm.get(
            f"{self.rxnorm.base_url}/rxcui.json", params={"name": name, "search": "2"}
        ).json()
        ids = data.get("idGroup", {}).get("rxnormId") or []
        if not ids:
            return None
        if len(ids) > 5:
            raise AmbiguousMedicineName("multiple_identities")
        references = []
        for identifier in ids:
            if not str(identifier).isdigit():
                return None
            reference = self._concept(str(identifier), name)
            if reference is None:
                raise AmbiguousMedicineName("unresolved_exact_match")
            references.append(reference)
        signatures = {
            tuple(sorted(normalize_search(i.name) for i in r.candidate.ingredients))
            for r in references
        }
        if len(signatures) != 1:
            raise AmbiguousMedicineName("different_ingredients")
        return references[0]

    def _concept(self, identifier: str, query: str) -> NameReference | None:
        url = f"{self.rxnorm.base_url}/rxcui/{identifier}"
        properties = (
            self.rxnorm.get(url + "/properties.json", params={}).json().get("properties") or {}
        )
        if str(properties.get("rxcui")) != identifier:
            return None
        kind = str(properties.get("tty") or "")
        if kind not in {"IN", "MIN", "PIN", "BN", "SCD", "SBD", "SCDF", "SBDF", "SCDC", "SBDC"}:
            return None
        if kind == "IN":
            chosen = properties
            ingredients = [properties]
        else:
            groups = (
                self.rxnorm.get(url + "/related.json", params={"tty": "IN MIN"})
                .json()
                .get("relatedGroup", {})
                .get("conceptGroup", [])
            )
            ingredients = [
                p for g in groups if g.get("tty") == "IN" for p in g.get("conceptProperties", [])
            ]
            combinations = [
                p for g in groups if g.get("tty") == "MIN" for p in g.get("conceptProperties", [])
            ]
            if not ingredients:
                return None
            if kind == "MIN":
                chosen = properties
            elif len(ingredients) == 1:
                chosen = ingredients[0]
            elif len(combinations) == 1:
                chosen = combinations[0]
                if {normalize_search(p["name"]) for p in ingredients} != {
                    normalize_search(p) for p in chosen["name"].split(" / ")
                }:
                    return None
            else:
                return None  # Distinct ingredient combinations cannot be merged into one medicine.
        chosen_id = str(chosen.get("rxcui") or "")
        chosen_name = str(chosen.get("name") or "")
        if not chosen_id.isdigit() or not chosen_name:
            return None
        raw = ProviderCandidate(
            external_id=chosen_id,
            canonical_name=chosen_name,
            generic_name=chosen_name,
            provider="rxnorm",
            provider_version=self.rxnorm.version,
            country="US",
            ingredients=tuple(Ingredient(name=str(p["name"])) for p in ingredients),
            identifiers=({"type": "rxcui", "value": chosen_id, "jurisdiction": "US"},),
            metadata={"term_type": "IN" if len(ingredients) == 1 else "MIN"},
        )
        relationship: Literal["brand", "generic", "synonym", "product"] = (
            "brand"
            if kind == "BN"
            else "generic"
            if normalize_search(query) == normalize_search(chosen_name)
            else "synonym"
            if kind in {"IN", "PIN", "MIN"}
            else "product"
        )
        return NameReference(
            candidate=self.service._rank(raw, chosen_name, None, None, None),
            relationship=relationship,
            sources=[
                citation(
                    "rxnorm",
                    "NLM RxNorm: medicine and ingredient reference",
                    url + "/properties.json",
                )
            ],
        )

    def _pubchem_name(self, name: str) -> NameReference | None:
        # Whole-name identity lookup only. No fuzzy matching, generated aliases or drug guesses.
        url = (
            "https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/name/"
            + quote(name, safe="")
            + "/property/Title/JSON"
        )
        response = self.service.client.get(url, params={"name_type": "complete"})
        if response.status_code == 404:
            return None
        response.raise_for_status()
        rows = response.json().get("PropertyTable", {}).get("Properties") or []
        if len(rows) != 1:
            return None
        row = rows[0]
        title = str(row.get("Title") or "")
        cid = str(row.get("CID") or "")
        if not title or not cid.isdigit() or normalize_search(title) == normalize_search(name):
            return None
        result = self._rxnorm_name(title)
        if result is None:
            return None
        return result.model_copy(
            update={
                "relationship": "synonym",
                "sources": [
                    citation(
                        "pubchem",
                        "NIH PubChem: name and compound reference",
                        "https://pubchem.ncbi.nlm.nih.gov/compound/" + cid,
                    ),
                    *result.sources,
                ],
            }
        )
