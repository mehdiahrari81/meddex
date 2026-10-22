import hashlib
import time
from dataclasses import asdict
from datetime import timedelta
from functools import partial
from typing import Any, cast
from uuid import UUID

import httpx
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.core.config import Settings
from app.core.time import utc_now
from app.models import (
    FeatureFlag,
    MedicalFact,
    MedicationIdentifier,
    MedicationIdentity,
    MedicationIngredient,
    MedicationProviderMapping,
    MedicationResolution,
    Prescription,
    PrescriptionItem,
    ProviderHealthEvent,
)
from app.providers.medication import (
    DailyMedProvider,
    DrapDatasetProvider,
    MedicationSearchProvider,
    MedlinePlusProvider,
    NotConfiguredInteractionProvider,
    PatientDrugInformationProvider,
    ProviderCandidate,
    ProviderFact,
    RegulatoryDrugLabelProvider,
    RxNormProvider,
    RxNormReferenceProvider,
    normalize_search,
)
from app.schemas.intelligence import MatchEvidence, MedicationCandidateRead
from app.services.provider_cache import ProviderCache


class MedicationIntelligenceService:
    def __init__(self, db: Session, settings: Settings, client: httpx.Client | None = None):
        self.db = db
        self.settings = settings
        self.client = client or httpx.Client(
            timeout=httpx.Timeout(settings.provider_timeout_seconds),
            follow_redirects=False,
            headers={"User-Agent": "MediExplain/1.0 medical-information-client"},
        )
        self.reference = RxNormReferenceProvider(db)
        self.rxnorm = RxNormProvider(self.client)
        self.medlineplus = MedlinePlusProvider(self.client)
        self.dailymed = DailyMedProvider(self.client)
        self.drap = DrapDatasetProvider(db)
        self.interactions = NotConfiguredInteractionProvider()
        self.cache = ProviderCache(db)

    def create_resolution(
        self,
        *,
        user_id: UUID,
        raw_value: str,
        input_origin: str,
        strength: str | None,
        dosage_form: str | None,
        country: str | None,
        prescription_item_id: str | None,
    ) -> MedicationResolution:
        if input_origin == "prescription":
            self._require_confirmed_prescription_item(user_id, prescription_item_id, raw_value)
        normalized = normalize_search(raw_value)
        resolution = MedicationResolution(
            user_id=user_id,
            input_origin=input_origin,
            raw_confirmed_value=raw_value,
            normalized_search_string=normalized,
            requested_strength=strength,
            requested_dosage_form=dosage_form,
            requested_country=country,
            prescription_item_client_id=prescription_item_id,
            state="searching",
            candidates=[],
            provider_failures=[],
        )
        self.db.add(resolution)
        self.db.flush()
        candidates: list[MedicationCandidateRead] = []
        failures: list[dict[str, object]] = []
        if self._provider_enabled(
            "drap_provider", self.settings.drap_dataset_enabled
        ) and country in {
            None,
            "PK",
        }:
            candidates.extend(
                self._run_search(self.drap, raw_value, country, strength, dosage_form, failures)
            )
        if self._provider_enabled("rxnorm_provider", self.settings.rxnorm_enabled):
            candidates.extend(
                self._rank(item, raw_value, strength, dosage_form, country)
                for item in self.reference.search(raw_value, country=country)
            )
            candidates.extend(
                self._run_search(self.rxnorm, raw_value, country, strength, dosage_form, failures)
            )
        deduped = self._deduplicate(candidates)
        resolution.candidates = [item.model_dump(mode="json") for item in deduped]
        resolution.provider_failures = failures
        resolution.state = self._state(deduped, failures)
        resolution.updated_at = utc_now()
        self.db.commit()
        return resolution

    def resolution(self, user_id: UUID, resolution_id: UUID) -> MedicationResolution | None:
        return self.db.scalar(
            select(MedicationResolution).where(
                MedicationResolution.id == resolution_id,
                MedicationResolution.user_id == user_id,
            )
        )

    def confirm(
        self, user_id: UUID, resolution_id: UUID, candidate_id: str
    ) -> tuple[MedicationResolution, MedicationIdentity]:
        resolution = self.resolution(user_id, resolution_id)
        if resolution is None:
            raise LookupError("resolution_not_found")
        candidate_data = next(
            (item for item in resolution.candidates if item.get("candidate_id") == candidate_id),
            None,
        )
        if candidate_data is None:
            raise ValueError("candidate_not_in_resolution")
        candidate = MedicationCandidateRead.model_validate(candidate_data)
        identity = self.reference_identity(candidate)
        resolution.selected_candidate_id = candidate_id
        resolution.medication_id = identity.id
        resolution.state = identity.verification_state
        resolution.updated_at = utc_now()
        self.db.commit()
        self.refresh_facts(identity)
        return resolution, self.identity(identity.id) or identity

    def reference_identity(self, candidate: MedicationCandidateRead) -> MedicationIdentity:
        """Cache a trusted reference identity without confirming any patient prescription."""
        mapping = self.db.scalar(
            select(MedicationProviderMapping).where(
                MedicationProviderMapping.provider == candidate.provider,
                MedicationProviderMapping.external_id == self._external_id(candidate.candidate_id),
            )
        )
        if mapping is not None:
            identity = self.identity(mapping.medication_id)
            assert identity is not None
        else:
            verification = (
                "local_registry_match"
                if candidate.provider == "drap_dataset"
                else "external_identity_verified"
            )
            identity = MedicationIdentity(
                canonical_display_name=candidate.canonical_name,
                normalized_name=normalize_search(candidate.canonical_name),
                generic_name=candidate.generic_name,
                brand_names=[candidate.brand_name] if candidate.brand_name else [],
                dosage_form=candidate.dosage_form,
                country=candidate.country,
                verification_state=verification,
            )
            identity.ingredients = [
                MedicationIngredient(
                    name=item.name,
                    normalized_name=normalize_search(item.name),
                    numerator_value=item.numerator_value,
                    numerator_unit=item.numerator_unit,
                    denominator_value=item.denominator_value,
                    denominator_unit=item.denominator_unit,
                    position=index,
                )
                for index, item in enumerate(candidate.ingredients)
            ]
            identity.identifiers = [
                MedicationIdentifier(
                    identifier_type=item.type,
                    value=item.value,
                    jurisdiction=item.jurisdiction,
                    provider=candidate.provider,
                )
                for item in candidate.identifiers
            ]
            identity.mappings = [
                MedicationProviderMapping(
                    provider=candidate.provider,
                    external_id=self._external_id(candidate.candidate_id),
                    provider_version=candidate.provider_version,
                    evidence={"signals": [item.model_dump() for item in candidate.evidence]},
                )
            ]
            self.db.add(identity)
            self.db.flush()
        self.db.commit()
        return identity

    def identity(self, medication_id: UUID) -> MedicationIdentity | None:
        return self.db.scalar(
            select(MedicationIdentity)
            .options(
                selectinload(MedicationIdentity.ingredients),
                selectinload(MedicationIdentity.identifiers),
                selectinload(MedicationIdentity.mappings),
                selectinload(MedicationIdentity.facts),
            )
            .where(MedicationIdentity.id == medication_id)
            .execution_options(populate_existing=True)
        )

    def refresh_facts(self, identity: MedicationIdentity) -> str:
        rxcui = next(
            (item.value for item in identity.identifiers if item.identifier_type == "rxcui"), None
        )
        overall = "current"
        configured: list[
            tuple[PatientDrugInformationProvider | RegulatoryDrugLabelProvider, str, timedelta]
        ] = []
        if self._provider_enabled("medlineplus_provider", self.settings.medlineplus_enabled):
            configured.append((self.medlineplus, "patient_information", timedelta(hours=24)))
        if self._provider_enabled("dailymed_provider", self.settings.dailymed_enabled):
            configured.append((self.dailymed, "label_sections", timedelta(days=7)))
        for provider, operation, ttl in configured:
            try:
                cached = self.cache.get_or_refresh(
                    provider=provider.name,
                    provider_version=provider.version,
                    operation=operation,
                    arguments={"medication": str(identity.id), "rxcui": rxcui or ""},
                    ttl=ttl,
                    loader=partial(self._facts_payload, provider, identity, rxcui),
                )
                if cached.state == "stale":
                    overall = "stale"
                self._store_facts(identity.id, cached.payload.get("facts", []))
            except (httpx.HTTPError, ValueError, KeyError):
                overall = "partial" if identity.facts else "source_unavailable"
        return overall

    def resolve_barcode(self, value: str) -> ProviderCandidate | None:
        if not self._provider_enabled("barcode_resolution", True) or not self._provider_enabled(
            "drap_provider", self.settings.drap_dataset_enabled
        ):
            return None
        return self.drap.resolve_barcode(value)

    def _provider_enabled(self, flag_key: str, configured: bool) -> bool:
        flag = self.db.get(FeatureFlag, flag_key)
        return configured and (flag is None or flag.enabled)

    def _run_search(
        self,
        provider: MedicationSearchProvider,
        query: str,
        country: str | None,
        strength: str | None,
        dosage_form: str | None,
        failures: list[dict[str, object]],
    ) -> list[MedicationCandidateRead]:
        started = time.monotonic()
        try:
            cached = self.cache.get_or_refresh(
                provider=provider.name,
                provider_version=provider.version,
                operation="search",
                arguments={"query": normalize_search(query), "country": country or ""},
                ttl=timedelta(hours=24),
                loader=lambda: {
                    "candidates": [
                        self._candidate_payload(item)
                        for item in provider.search(query, country=country)
                    ]
                },
            )
            payloads = cached.payload.get("candidates")
            if not isinstance(payloads, list):
                raise TypeError("candidate_payload_invalid")
            raw = [self._candidate_from_payload(item) for item in payloads]
            candidates = [self._rank(item, query, strength, dosage_form, country) for item in raw]
            self._health(provider.name, "search", True, started, None, cached.state)
            return candidates
        except (httpx.HTTPError, ValueError, KeyError, TypeError):
            provider_name = provider.name
            failures.append({"provider": provider_name, "code": "provider_unavailable"})
            self._health(provider_name, "search", False, started, "provider_unavailable", None)
            return []

    def _rank(
        self,
        item: ProviderCandidate,
        query: str,
        strength: str | None,
        dosage_form: str | None,
        country: str | None,
    ) -> MedicationCandidateRead:
        normalized_query = normalize_search(query)
        names = [item.canonical_name, item.generic_name or "", item.brand_name or ""]
        normalized_names = [normalize_search(value) for value in names if value]
        exact = normalized_query in normalized_names
        partial = any(
            normalized_query in value or value in normalized_query for value in normalized_names
        )
        strength_match = not strength or normalize_search(strength) in normalize_search(
            item.strength or item.canonical_name
        )
        form_match = not dosage_form or normalize_search(dosage_form) in normalize_search(
            item.dosage_form or item.canonical_name
        )
        country_match = not country or item.country == country
        evidence = [
            MatchEvidence(
                signal="name_exact", matched=exact, requested=query, candidate=item.canonical_name
            ),
            MatchEvidence(
                signal="name_partial",
                matched=partial,
                requested=query,
                candidate=item.canonical_name,
            ),
            MatchEvidence(
                signal="strength",
                matched=strength_match,
                requested=strength,
                candidate=item.strength,
            ),
            MatchEvidence(
                signal="dosage_form",
                matched=form_match,
                requested=dosage_form,
                candidate=item.dosage_form,
            ),
            MatchEvidence(
                signal="country", matched=country_match, requested=country, candidate=item.country
            ),
        ]
        score = min(
            1.0,
            (0.55 if exact else 0.30 if partial else 0)
            + (0.20 if strength and strength_match else 0)
            + (0.15 if dosage_form and form_match else 0)
            + (0.10 if country and country_match else 0),
        )
        exact_identity = exact and strength_match and form_match and country_match
        return MedicationCandidateRead(
            candidate_id=f"{item.provider}:{item.external_id}",
            canonical_name=item.canonical_name,
            generic_name=item.generic_name,
            brand_name=item.brand_name,
            ingredients=[ingredient.as_dict() for ingredient in item.ingredients],
            strength=item.strength,
            dosage_form=item.dosage_form,
            country=item.country,
            provider=item.provider,
            provider_version=item.provider_version,
            identifiers=list(item.identifiers),
            evidence=evidence,
            match_score=score,
            exact_identity=exact_identity,
        )

    @staticmethod
    def _state(candidates: list[MedicationCandidateRead], failures: list[dict[str, object]]) -> str:
        if not candidates:
            return "provider_unavailable" if failures else "no_trusted_match"
        exact = [item for item in candidates if item.exact_identity]
        if len(exact) == 1 and len(candidates) == 1:
            return "candidates_found"
        return "user_selection_required" if len(candidates) == 1 else "ambiguous"

    @staticmethod
    def _deduplicate(candidates: list[MedicationCandidateRead]) -> list[MedicationCandidateRead]:
        unique: dict[str, MedicationCandidateRead] = {}
        for item in sorted(candidates, key=lambda value: value.match_score, reverse=True):
            key = item.candidate_id
            if key not in unique:
                unique[key] = item
        return list(unique.values())[:30]

    def _require_confirmed_prescription_item(
        self, user_id: UUID, client_item_id: str | None, raw_value: str
    ) -> None:
        if not client_item_id:
            raise ValueError("confirmed_prescription_item_required")
        item = self.db.scalar(
            select(PrescriptionItem)
            .join(Prescription, Prescription.id == PrescriptionItem.prescription_id)
            .where(
                Prescription.user_id == user_id,
                PrescriptionItem.client_id == client_item_id,
                Prescription.verification_state == "readyForMedicationLookup",
                Prescription.user_confirmed_at.is_not(None),
                PrescriptionItem.state == "readyForLookup",
            )
        )
        if item is None:
            raise ValueError("confirmed_prescription_item_required")
        name_field = next(
            (field for field in item.fields if field.get("type") == "medicationName"), None
        )
        if not name_field or not name_field.get("user_confirmed"):
            raise ValueError("confirmed_prescription_item_required")
        if normalize_search(str(name_field.get("current_value") or "")) != normalize_search(
            raw_value
        ):
            raise ValueError("prescription_value_mismatch")

    def _facts_payload(
        self,
        provider: PatientDrugInformationProvider | RegulatoryDrugLabelProvider,
        identity: MedicationIdentity,
        rxcui: str | None,
    ) -> dict[str, object]:
        if isinstance(provider, MedlinePlusProvider):
            facts = provider.patient_information(
                rxcui=rxcui, name=identity.canonical_display_name, language="en"
            )
        elif isinstance(provider, DailyMedProvider):
            facts = provider.label_sections(rxcui=rxcui, name=identity.canonical_display_name)
        else:
            facts = []

        payloads = []
        for fact in facts:
            data = asdict(fact)
            if data.get("retrieved_at"):
                data["retrieved_at"] = data["retrieved_at"].isoformat()
            if data.get("source_updated_at"):
                data["source_updated_at"] = data["source_updated_at"].isoformat()
            payloads.append(data)
        return {"facts": payloads}

    def _store_facts(self, medication_id: UUID, payloads: object) -> None:
        if not isinstance(payloads, list):
            return
        for payload in payloads:
            if not isinstance(payload, dict):
                continue
            payload_dict = cast(dict[str, Any], payload).copy()
            from datetime import datetime

            if isinstance(payload_dict.get("retrieved_at"), str):
                payload_dict["retrieved_at"] = datetime.fromisoformat(payload_dict["retrieved_at"])
            if isinstance(payload_dict.get("source_updated_at"), str):
                payload_dict["source_updated_at"] = datetime.fromisoformat(
                    payload_dict["source_updated_at"]
                )
            fact = ProviderFact(**payload_dict)
            content_hash = hashlib.sha256(fact.content.encode()).hexdigest()
            existing = self.db.scalar(
                select(MedicalFact).where(
                    MedicalFact.medication_id == medication_id,
                    MedicalFact.provider == fact.provider,
                    MedicalFact.source_id == fact.source_id,
                    MedicalFact.fact_type == fact.fact_type,
                    MedicalFact.content_hash == content_hash,
                )
            )
            if existing is None:
                self.db.add(
                    MedicalFact(
                        medication_id=medication_id,
                        fact_type=fact.fact_type,
                        content=fact.content,
                        provider=fact.provider,
                        source_id=fact.source_id,
                        source_title=fact.source_title,
                        source_section=fact.source_section,
                        citation_reference=fact.citation_reference,
                        jurisdiction=fact.jurisdiction,
                        language=fact.language,
                        content_version=fact.content_version,
                        content_hash=content_hash,
                        retrieved_at=fact.retrieved_at,
                        source_updated_at=fact.source_updated_at,
                    )
                )
                self.db.flush()
        self.db.commit()

    @staticmethod
    def _external_id(candidate_id: str) -> str:
        return candidate_id.split(":", maxsplit=1)[1]

    @staticmethod
    def _candidate_payload(item: ProviderCandidate) -> dict[str, object]:
        return {
            "external_id": item.external_id,
            "canonical_name": item.canonical_name,
            "provider": item.provider,
            "provider_version": item.provider_version,
            "generic_name": item.generic_name,
            "brand_name": item.brand_name,
            "ingredients": [ingredient.as_dict() for ingredient in item.ingredients],
            "strength": item.strength,
            "dosage_form": item.dosage_form,
            "country": item.country,
            "identifiers": list(item.identifiers),
            "metadata": item.metadata,
        }

    @staticmethod
    def _candidate_from_payload(payload: object) -> ProviderCandidate:
        if not isinstance(payload, dict):
            raise TypeError("candidate_payload_invalid")
        from app.providers.medication import Ingredient

        return ProviderCandidate(
            external_id=str(payload["external_id"]),
            canonical_name=str(payload["canonical_name"]),
            provider=str(payload["provider"]),
            provider_version=str(payload["provider_version"]),
            generic_name=payload.get("generic_name")
            if isinstance(payload.get("generic_name"), str)
            else None,
            brand_name=payload.get("brand_name")
            if isinstance(payload.get("brand_name"), str)
            else None,
            ingredients=tuple(
                Ingredient(**cast(dict[str, Any], item))
                for item in cast(list[object], payload.get("ingredients", []))
            ),
            strength=payload.get("strength") if isinstance(payload.get("strength"), str) else None,
            dosage_form=payload.get("dosage_form")
            if isinstance(payload.get("dosage_form"), str)
            else None,
            country=payload.get("country") if isinstance(payload.get("country"), str) else None,
            identifiers=tuple(
                cast(dict[str, str | None], item)
                for item in cast(list[object], payload.get("identifiers", []))
            ),
            metadata=cast(dict[str, str], payload.get("metadata", {})),
        )

    def _health(
        self,
        provider: str,
        operation: str,
        success: bool,
        started: float,
        error: str | None,
        cache_status: str | None,
    ) -> None:
        self.db.add(
            ProviderHealthEvent(
                provider=provider,
                operation=operation,
                success=success,
                latency_ms=(time.monotonic() - started) * 1000,
                safe_error_code=error,
                cache_status=cache_status,
                circuit_state="closed",
            )
        )
        self.db.commit()
