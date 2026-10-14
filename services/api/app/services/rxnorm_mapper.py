import logging

import httpx
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.time import utc_now
from app.models import MedicationIdentity, MedicationProviderMapping
from app.providers.medication import ProviderCandidate, RxNormProvider, normalize_search

logger = logging.getLogger(__name__)


class RxNormMapper:
    def __init__(self, db: Session, rxnorm: RxNormProvider):
        self.db = db
        self.rxnorm = rxnorm

    def map_drap_to_rxnorm(self, limit: int = 100) -> int:
        """
        Map only a single fully evidenced ingredient/strength/form equivalent.

        Search ranking or a shared generic name cannot verify product equivalence.
        Incomplete provider candidates remain unmapped for independent review.
        """
        identities = self.db.scalars(
            select(MedicationIdentity)
            .outerjoin(
                MedicationProviderMapping,
                (MedicationProviderMapping.medication_id == MedicationIdentity.id)
                & (MedicationProviderMapping.provider == "rxnorm"),
            )
            .where(MedicationIdentity.country == "PK", MedicationProviderMapping.id.is_(None))
            .limit(limit)
        ).all()

        mapped_count = 0
        for identity in identities:
            query = identity.generic_name or identity.canonical_display_name
            try:
                candidates = [
                    candidate
                    for candidate in self.rxnorm.search(query, country="US")
                    if self._equivalent(identity, candidate)
                ]
                if len(candidates) == 1:
                    best = candidates[0]
                    mapping = MedicationProviderMapping(
                        medication_id=identity.id,
                        provider="rxnorm",
                        external_id=best.external_id,
                        provider_version=best.provider_version,
                        evidence={
                            "source": "rxnorm_structured_equivalence",
                            "query": query,
                            "canonical": best.canonical_name,
                        },
                        verified_at=utc_now(),
                    )
                    self.db.add(mapping)
                    mapped_count += 1
            except (httpx.HTTPError, ValueError, TypeError):
                logger.warning("rxnorm_mapping_provider_unavailable")

        self.db.commit()
        return mapped_count

    @staticmethod
    def _equivalent(identity: MedicationIdentity, candidate: ProviderCandidate) -> bool:
        if not identity.dosage_form or not candidate.dosage_form:
            return False
        if normalize_search(identity.dosage_form) != normalize_search(candidate.dosage_form):
            return False
        if not identity.ingredients or len(identity.ingredients) != len(candidate.ingredients):
            return False
        local = sorted(
            (
                normalize_search(item.name),
                item.numerator_value,
                item.numerator_unit,
                item.denominator_value,
                item.denominator_unit,
            )
            for item in identity.ingredients
        )
        remote = sorted(
            (
                normalize_search(item.name),
                item.numerator_value,
                item.numerator_unit,
                item.denominator_value,
                item.denominator_unit,
            )
            for item in candidate.ingredients
        )
        # Exact structured values are conservative: never infer missing strengths.
        return all(row[1] and row[2] for row in local) and local == remote
