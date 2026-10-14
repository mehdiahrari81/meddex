import re
import time
import unicodedata
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from datetime import datetime
from typing import Any, ClassVar
from urllib.parse import urlencode

import httpx
from defusedxml import ElementTree
from sqlalchemy import or_, select
from sqlalchemy.orm import Session, selectinload

from app.core.time import utc_now
from app.models import MedicationIdentifier, MedicationIdentity, MedicationProviderMapping

_STRENGTH = re.compile(
    r"(?P<value>\d+(?:\.\d+)?)\s*(?P<unit>mcg|μg|mg|g|ml|mL|units?|%)(?:\s*/\s*(?P<den>\d+(?:\.\d+)?\s*)?(?P<den_unit>ml|mL|g))?",
    re.IGNORECASE,
)
_FORM_WORDS = (
    "oral tablet",
    "oral capsule",
    "extended release tablet",
    "delayed release tablet",
    "injection",
    "suspension",
    "solution",
    "cream",
    "ointment",
    "tablet",
    "capsule",
)


def normalize_search(value: str) -> str:
    normalized = unicodedata.normalize("NFKC", value).casefold()
    normalized = re.sub(r"[^\w.%μ/-]+", " ", normalized, flags=re.UNICODE)
    return " ".join(normalized.split())


@dataclass(frozen=True)
class Ingredient:
    name: str
    numerator_value: str | None = None
    numerator_unit: str | None = None
    denominator_value: str | None = None
    denominator_unit: str | None = None

    def as_dict(self) -> dict[str, str | None]:
        return {
            "name": self.name,
            "numerator_value": self.numerator_value,
            "numerator_unit": self.numerator_unit,
            "denominator_value": self.denominator_value,
            "denominator_unit": self.denominator_unit,
        }


@dataclass(frozen=True)
class ProviderCandidate:
    external_id: str
    canonical_name: str
    provider: str
    provider_version: str
    generic_name: str | None = None
    brand_name: str | None = None
    ingredients: tuple[Ingredient, ...] = ()
    strength: str | None = None
    dosage_form: str | None = None
    country: str | None = None
    identifiers: tuple[dict[str, str | None], ...] = ()
    metadata: dict[str, str] = field(default_factory=dict)


@dataclass(frozen=True)
class ProviderFact:
    fact_type: str
    content: str
    provider: str
    source_id: str
    source_title: str
    source_section: str
    citation_reference: str
    jurisdiction: str | None
    language: str
    content_version: str
    retrieved_at: datetime
    source_updated_at: datetime | None = None


class MedicationSearchProvider(ABC):
    name: str
    version: str

    @abstractmethod
    def search(self, query: str, *, country: str | None = None) -> list[ProviderCandidate]: ...


class DrugNormalizationProvider(MedicationSearchProvider):
    pass


class PatientDrugInformationProvider(ABC):
    name: str
    version: str

    @abstractmethod
    def patient_information(
        self, *, rxcui: str | None, name: str, language: str
    ) -> list[ProviderFact]: ...


class RegulatoryDrugLabelProvider(ABC):
    name: str
    version: str

    @abstractmethod
    def label_sections(self, *, rxcui: str | None, name: str) -> list[ProviderFact]: ...


class CountryDrugRegistryProvider(MedicationSearchProvider):
    pass


class BarcodeResolutionProvider(ABC):
    @abstractmethod
    def resolve_barcode(self, value: str) -> ProviderCandidate | None: ...


class InteractionProvider(ABC):
    @property
    @abstractmethod
    def state(self) -> str: ...

    @abstractmethod
    def interactions(self, medication_ids: list[str]) -> list[dict[str, object]]: ...


class NotConfiguredInteractionProvider(InteractionProvider):
    @property
    def state(self) -> str:
        return "not_configured"

    def interactions(self, medication_ids: list[str]) -> list[dict[str, object]]:
        return []


class _SafeHttpProvider:
    def __init__(self, client: httpx.Client, *, failure_threshold: int = 3, cooldown: int = 60):
        self.client = client
        self.failure_threshold = failure_threshold
        self.cooldown = cooldown
        self._failures = 0
        self._opened_at: float | None = None

    @property
    def circuit_state(self) -> str:
        if self._opened_at is None:
            return "closed"
        if time.monotonic() - self._opened_at >= self.cooldown:
            return "half_open"
        return "open"

    def get(self, url: str, *, params: dict[str, str]) -> httpx.Response:
        if self.circuit_state == "open":
            raise httpx.RequestError("provider_circuit_open")
        try:
            response = self.client.get(url, params=params)
            response.raise_for_status()
        except httpx.HTTPError:
            self._failures += 1
            if self._failures >= self.failure_threshold:
                self._opened_at = time.monotonic()
            raise
        self._failures = 0
        self._opened_at = None
        return response


class RxNormProvider(_SafeHttpProvider, DrugNormalizationProvider):
    name = "rxnorm"
    version = "REST-exact-v2"
    base_url = "https://rxnav.nlm.nih.gov/REST"

    def search(self, query: str, *, country: str | None = None) -> list[ProviderCandidate]:
        response = self.get(
            f"{self.base_url}/Prescribe/drugs.json",
            params={"name": query, "expand": "psn"},
        )
        groups = response.json().get("drugGroup", {}).get("conceptGroup", []) or []
        if not any(group.get("conceptProperties") for group in groups):
            exact = self.get(
                f"{self.base_url}/rxcui.json", params={"name": query, "search": "0"}
            ).json()
            for identifier in (exact.get("idGroup", {}).get("rxnormId") or [])[:5]:
                properties = (
                    self.get(f"{self.base_url}/rxcui/{identifier}/properties.json", params={})
                    .json()
                    .get("properties")
                )
                if properties:
                    groups.append({"conceptProperties": [properties]})
        candidates: list[ProviderCandidate] = []
        for group in groups:
            for concept in group.get("conceptProperties") or []:
                name = str(concept.get("name") or "").strip()
                rxcui = str(concept.get("rxcui") or "").strip()
                term_type = str(concept.get("tty") or group.get("tty") or "")
                if not name or not rxcui or term_type in {"BPCK", "GPCK"}:
                    continue
                lowered = name.casefold()
                form = next((item for item in _FORM_WORDS if item in lowered), None)
                ingredients_list = []
                strengths = []
                for part in re.split(r"\s+/\s+", name.split("[")[0]):
                    strength_match = _STRENGTH.search(part)
                    ingredient_name = (
                        part[: strength_match.start()] if strength_match else part
                    ).strip()
                    if not ingredient_name:
                        continue
                    if strength_match:
                        strengths.append(strength_match.group(0))
                    ingredients_list.append(
                        Ingredient(
                            name=ingredient_name,
                            numerator_value=strength_match["value"] if strength_match else None,
                            numerator_unit=strength_match["unit"] if strength_match else None,
                            denominator_value=(strength_match["den"] or "1").strip()
                            if strength_match and strength_match["den_unit"]
                            else None,
                            denominator_unit=strength_match["den_unit"] if strength_match else None,
                        )
                    )
                ingredients = tuple(ingredients_list)
                ingredient_text = " / ".join(item.name for item in ingredients)
                strength = " / ".join(strengths) or None
                brand_match = re.search(r"\[([^]]+)]", name)
                candidates.append(
                    ProviderCandidate(
                        external_id=rxcui,
                        canonical_name=name,
                        provider=self.name,
                        provider_version=self.version,
                        generic_name=ingredient_text or None,
                        brand_name=brand_match.group(1) if brand_match else None,
                        ingredients=ingredients,
                        strength=strength,
                        dosage_form=form,
                        country="US",
                        identifiers=({"type": "rxcui", "value": rxcui, "jurisdiction": "US"},),
                        metadata={"term_type": term_type},
                    )
                )
        unique: dict[str, ProviderCandidate] = {item.external_id: item for item in candidates}
        # Rank the complete result in the service before applying its presentation limit.
        return list(unique.values())


class MedlinePlusProvider(_SafeHttpProvider, PatientDrugInformationProvider):
    name = "medlineplus_connect"
    version = "HL7-Infobutton-current"
    base_url = "https://connect.medlineplus.gov/service"

    def patient_information(
        self, *, rxcui: str | None, name: str, language: str
    ) -> list[ProviderFact]:
        code_system = "2.16.840.1.113883.6.88" if rxcui else "2.16.840.1.113883.6.69"
        params = {
            "mainSearchCriteria.v.cs": code_system,
            "mainSearchCriteria.v.dn": name,
            "informationRecipient.languageCode.c": "es" if language == "es" else "en",
            "knowledgeResponseType": "application/json",
        }
        if rxcui:
            params["mainSearchCriteria.v.c"] = rxcui
        response = self.get(self.base_url, params=params)
        feed = response.json().get("feed") or {}
        retrieved = utc_now()
        facts: list[ProviderFact] = []
        for entry in feed.get("entry") or []:
            title = str(entry.get("title", {}).get("_value") or "MedlinePlus drug information")
            links = entry.get("link") or []
            url = next(
                (
                    str(link.get("href"))
                    for link in links
                    if link.get("href", "").startswith("https://")
                ),
                None,
            )
            if not url:
                continue
            source_id = str(entry.get("id", {}).get("_value") or url)
            summary = str(entry.get("summary", {}).get("_value") or "").strip()
            if not summary:
                continue
            content = _strip_html(summary)
            facts.append(
                ProviderFact(
                    fact_type="patient_information",
                    content=content,
                    provider=self.name,
                    source_id=source_id,
                    source_title=title,
                    source_section="Patient information",
                    citation_reference=url,
                    jurisdiction="US",
                    language=language,
                    content_version=self.version,
                    retrieved_at=retrieved,
                )
            )
        return facts


class DailyMedProvider(_SafeHttpProvider, RegulatoryDrugLabelProvider):
    name = "dailymed"
    version = "v2"
    base_url = "https://dailymed.nlm.nih.gov/dailymed/services/v2"
    section_codes: ClassVar[dict[str, str]] = {
        "34067-9": "indications",
        "34068-7": "dosage_administration",
        "34070-3": "contraindications",
        "34071-1": "warnings",
        "43685-7": "warnings_precautions",
        "34084-4": "adverse_reactions",
        "44425-7": "storage",
    }

    def label_sections(self, *, rxcui: str | None, name: str) -> list[ProviderFact]:
        params = {"pagesize": "5", "page": "1"}
        params["rxcui" if rxcui else "drug_name"] = rxcui or name
        search = self.get(f"{self.base_url}/spls.json", params=params).json()
        records = search.get("data") or []
        facts: list[ProviderFact] = []
        for record in records[:2]:
            set_id = str(record.get("setid") or "").strip()
            if not set_id:
                continue
            response = self.get(f"{self.base_url}/spls/{set_id}.xml", params={})
            facts.extend(self._parse_spl(response.content, set_id, record))
        return facts

    def _parse_spl(self, xml: bytes, set_id: str, record: dict[str, Any]) -> list[ProviderFact]:
        root = ElementTree.fromstring(xml)
        retrieved = utc_now()
        title = str(record.get("title") or record.get("drug_name") or "DailyMed label")
        version = str(record.get("spl_version") or self.version)
        facts: list[ProviderFact] = []
        for section in root.findall(".//{*}section"):
            code_node = section.find("./{*}code")
            code = code_node.attrib.get("code", "") if code_node is not None else ""
            fact_type = self.section_codes.get(code)
            if not fact_type:
                continue
            heading_node = section.find("./{*}title")
            text_node = section.find("./{*}text")
            content = (
                " ".join("".join(text_node.itertext()).split()) if text_node is not None else ""
            )
            if not content:
                continue
            facts.append(
                ProviderFact(
                    fact_type=fact_type,
                    content=content[:12_000],
                    provider=self.name,
                    source_id=set_id,
                    source_title=title,
                    source_section=(
                        " ".join(heading_node.itertext()).strip()
                        if heading_node is not None
                        else fact_type
                    ),
                    citation_reference=f"https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid={set_id}",
                    jurisdiction="US",
                    language="en",
                    content_version=version,
                    retrieved_at=retrieved,
                )
            )
        return facts


class DrapDatasetProvider(CountryDrugRegistryProvider, BarcodeResolutionProvider):
    name = "drap_dataset"
    version = "admin-imported"

    def __init__(self, db: Session):
        self.db = db

    def search(self, query: str, *, country: str | None = None) -> list[ProviderCandidate]:
        if country not in {None, "PK"}:
            return []
        needle = f"%{normalize_search(query)}%"
        identities = (
            self.db.scalars(
                select(MedicationIdentity)
                .options(
                    selectinload(MedicationIdentity.ingredients),
                    selectinload(MedicationIdentity.identifiers),
                    selectinload(MedicationIdentity.mappings),
                )
                .join(MedicationProviderMapping)
                .where(
                    MedicationProviderMapping.provider == self.name,
                    MedicationIdentity.country == "PK",
                    or_(
                        MedicationIdentity.normalized_name.ilike(needle),
                        MedicationIdentity.generic_name.ilike(needle),
                    ),
                )
                .order_by(MedicationIdentity.canonical_display_name)
                .limit(25)
            )
            .unique()
            .all()
        )
        return [self._candidate(item) for item in identities]

    def resolve_barcode(self, value: str) -> ProviderCandidate | None:
        identity = self.db.scalar(
            select(MedicationIdentity)
            .options(
                selectinload(MedicationIdentity.ingredients),
                selectinload(MedicationIdentity.identifiers),
                selectinload(MedicationIdentity.mappings),
            )
            .join(MedicationIdentifier)
            .where(
                MedicationIdentifier.identifier_type.in_(["barcode", "gtin"]),
                MedicationIdentifier.value == value,
                MedicationIdentifier.provider == self.name,
            )
        )
        return self._candidate(identity) if identity else None

    def _candidate(self, identity: MedicationIdentity) -> ProviderCandidate:
        mapping = next(item for item in identity.mappings if item.provider == self.name)
        return ProviderCandidate(
            external_id=mapping.external_id,
            canonical_name=identity.canonical_display_name,
            provider=self.name,
            provider_version=mapping.provider_version,
            generic_name=identity.generic_name,
            brand_name=identity.brand_names[0] if identity.brand_names else None,
            ingredients=tuple(
                Ingredient(
                    name=item.name,
                    numerator_value=item.numerator_value,
                    numerator_unit=item.numerator_unit,
                    denominator_value=item.denominator_value,
                    denominator_unit=item.denominator_unit,
                )
                for item in sorted(identity.ingredients, key=lambda item: item.position)
            ),
            dosage_form=identity.dosage_form,
            country="PK",
            identifiers=tuple(
                {
                    "type": item.identifier_type,
                    "value": item.value,
                    "jurisdiction": item.jurisdiction,
                }
                for item in identity.identifiers
            ),
            metadata={"internal_id": str(identity.id)},
        )


def _strip_html(value: str) -> str:
    return " ".join(re.sub(r"<[^>]+>", " ", value).split())[:12_000]


def source_url_with_query(base: str, params: dict[str, str]) -> str:
    return f"{base}?{urlencode(params)}"
