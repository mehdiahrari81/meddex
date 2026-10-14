import hashlib
import json
import re
from typing import ClassVar, cast
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.time import utc_now
from app.models import (
    AuditEvent,
    ContentImportJob,
    GovernedContent,
    GovernedContentRevision,
    MedicationIdentifier,
    MedicationIdentity,
    MedicationIngredient,
    MedicationProviderMapping,
)
from app.providers.medication import normalize_search
from app.services.content_import import ContentImporter


class GovernanceService:
    transitions: ClassVar[dict[tuple[str, str], str]] = {
        ("draft", "submit_review"): "in_review",
        ("in_review", "approve"): "approved",
        ("in_review", "reject"): "draft",
        ("approved", "publish"): "published",
        ("published", "deprecate"): "deprecated",
        ("deprecated", "archive"): "archived",
    }

    def __init__(self, db: Session):
        self.db = db

    def create_revision(
        self,
        *,
        stable_id: str,
        content_type: str,
        content: dict[str, object],
        source_metadata: dict[str, object],
        reason: str,
        actor_id: UUID,
        permissions: list[str],
        request_id: str,
    ) -> GovernedContent:
        if content_type == "dataset":
            ContentImporter(self.db).validate(content)
        record = self.db.get(GovernedContent, stable_id)
        if record is None:
            record = GovernedContent(
                stable_id=stable_id,
                content_type=content_type,
                lifecycle_state="draft",
                current_revision=0,
            )
            self.db.add(record)
            self.db.flush()
        if record.content_type != content_type:
            raise ValueError("content_type_immutable")
        record.current_revision += 1
        record.lifecycle_state = "draft"
        record.updated_at = utc_now()
        self.db.add(
            GovernedContentRevision(
                stable_id=stable_id,
                revision=record.current_revision,
                content=content,
                source_metadata=source_metadata,
                author_id=actor_id,
                change_reason=reason,
                review_state="draft",
            )
        )
        self.audit(actor_id, permissions, "content.revise", "content", stable_id, request_id)
        self.db.commit()
        return record

    def workflow(
        self,
        *,
        stable_id: str,
        action: str,
        reason: str,
        confirmation: str | None,
        actor_id: UUID,
        permissions: list[str],
        request_id: str,
    ) -> GovernedContent:
        record = self.db.get(GovernedContent, stable_id)
        if record is None:
            raise LookupError("content_not_found")
        next_state = self.transitions.get((record.lifecycle_state, action))
        if next_state is None:
            raise ValueError("invalid_workflow_transition")
        if action in {"publish", "deprecate", "archive"} and confirmation != stable_id:
            raise ValueError("typed_confirmation_required")
        revision = self.db.scalar(
            select(GovernedContentRevision).where(
                GovernedContentRevision.stable_id == stable_id,
                GovernedContentRevision.revision == record.current_revision,
            )
        )
        assert revision is not None
        if action == "approve" and revision.author_id == actor_id:
            raise ValueError("independent_reviewer_required")
        now = utc_now()
        record.lifecycle_state = next_state
        record.updated_at = now
        revision.review_state = next_state
        if action in {"approve", "reject"}:
            revision.reviewer_id = actor_id
            revision.reviewed_at = now
        if action == "publish":
            if record.content_type == "dataset":
                importer = ContentImporter(self.db)
                if not importer.import_document(revision.content, dry_run=True).changed:
                    raise ValueError("reference_release_requires_a_new_dataset_version")
                importer.import_document(revision.content, commit=False)
            record.published_revision = record.current_revision
            revision.published_at = now
        self.audit(
            actor_id,
            permissions,
            f"content.{action}",
            "content",
            stable_id,
            request_id,
            {"reason": reason, "revision": record.current_revision},
        )
        self.db.commit()
        return record

    def dry_run_import(
        self,
        *,
        dataset_type: str,
        source_name: str,
        source_version: str,
        records: list[dict[str, object]],
        actor_id: UUID,
        permissions: list[str],
        request_id: str,
    ) -> ContentImportJob:
        valid: list[dict[str, object]] = []
        rejected: list[dict[str, object]] = []
        seen: set[str] = set()
        for index, record in enumerate(records):
            try:
                stable_id = self._validate_import_record(dataset_type, record)
                if stable_id in seen:
                    raise ValueError("duplicate_stable_id")
                seen.add(stable_id)
                valid.append(record)
            except (KeyError, TypeError, ValueError) as error:
                rejected.append({"row": index + 1, "reason": str(error)})
        payload = {"records": valid}
        content_hash = hashlib.sha256(
            json.dumps(payload, sort_keys=True, separators=(",", ":")).encode()
        ).hexdigest()
        report: dict[str, object] = {
            "added": 0,
            "updated": 0,
            "unchanged": 0,
            "deprecated": 0,
            "rejected": len(rejected),
            "warnings": rejected,
        }
        counts = {"added": 0, "updated": 0, "unchanged": 0}
        for record in valid:
            existing = self.db.scalar(
                select(MedicationProviderMapping).where(
                    MedicationProviderMapping.provider == "drap_dataset",
                    MedicationProviderMapping.external_id == str(record["registration_id"]).strip(),
                )
            )
            if existing is None:
                counts["added"] += 1
            elif (
                existing.evidence.get("record_hash") == self._record_hash(record)
                and existing.provider_version == source_version
            ):
                counts["unchanged"] += 1
            else:
                counts["updated"] += 1
        report.update(counts)
        job = ContentImportJob(
            dataset_type=dataset_type,
            source_name=source_name,
            source_version=source_version,
            content_hash=content_hash,
            status="validated" if not rejected else "validation_failed",
            dry_run=True,
            report=report,
            staged_payload=payload,
            created_by=actor_id,
        )
        self.db.add(job)
        self.audit(actor_id, permissions, "import.dry_run", "import_job", "pending", request_id)
        self.db.commit()
        return job

    def apply_import(
        self,
        *,
        job_id: UUID,
        confirmation: str,
        actor_id: UUID,
        permissions: list[str],
        request_id: str,
    ) -> ContentImportJob:
        job = self.db.get(ContentImportJob, job_id)
        if job is None:
            raise LookupError("import_not_found")
        if job.status != "validated" or confirmation != str(job.id):
            raise ValueError("validated_job_and_typed_confirmation_required")
        if job.dataset_type == "drap_products":
            records = cast(list[dict[str, object]], job.staged_payload.get("records", []))
            for record in records:
                self._upsert_drap(record, job.source_version)
        else:
            raise ValueError("import_apply_not_supported_for_dataset")
        job.status = "applied"
        job.dry_run = False
        job.applied_by = actor_id
        job.applied_at = utc_now()
        self.audit(actor_id, permissions, "import.apply", "import_job", str(job.id), request_id)
        self.db.commit()
        return job

    def _upsert_drap(self, record: dict[str, object], version: str) -> None:
        registration_id = str(record["registration_id"]).strip()
        mapping = self.db.scalar(
            select(MedicationProviderMapping).where(
                MedicationProviderMapping.provider == "drap_dataset",
                MedicationProviderMapping.external_id == registration_id,
            )
        )
        identity: MedicationIdentity
        evidence: dict[str, object] = {
            "source": "approved_admin_import",
            "record_hash": self._record_hash(record),
            "manufacturer": str(record.get("manufacturer") or ""),
            "raw_composition": str(record.get("raw_composition") or ""),
        }
        if mapping is None:
            identity = MedicationIdentity(
                canonical_display_name=str(record["brand_name"]).strip(),
                normalized_name=normalize_search(str(record["brand_name"])),
                generic_name=str(record["generic_name"]).strip(),
                brand_names=[str(record["brand_name"]).strip()],
                dosage_form=str(record.get("dosage_form") or "").strip() or None,
                country="PK",
                verification_state="local_registry_match",
            )
            self.db.add(identity)
            self.db.flush()
            mapping = MedicationProviderMapping(
                medication_id=identity.id,
                provider="drap_dataset",
                external_id=registration_id,
                provider_version=version,
                evidence=evidence,
            )
            self.db.add(mapping)
        else:
            mapping.evidence = evidence
            loaded_identity = self.db.get(MedicationIdentity, mapping.medication_id)
            assert loaded_identity is not None
            identity = loaded_identity
        mapping.provider_version = version
        identity.canonical_display_name = str(record["brand_name"]).strip()
        identity.normalized_name = normalize_search(str(record["brand_name"]))
        identity.generic_name = str(record["generic_name"]).strip()
        identity.brand_names = [str(record["brand_name"]).strip()]
        identity.dosage_form = str(record.get("dosage_form") or "").strip() or None
        identity.ingredients.clear()
        ingredients = cast(list[dict[str, object]], record["ingredients"])
        for index, ingredient in enumerate(ingredients):
            unit = str(ingredient.get("unit") or "")
            concentration = re.fullmatch(r"([^/]+)/(?:(\d+(?:\.\d+)?)\s*)?([A-Za-zμ%]+)", unit)
            identity.ingredients.append(
                MedicationIngredient(
                    name=str(ingredient["name"]).strip(),
                    normalized_name=normalize_search(str(ingredient["name"])),
                    numerator_value=(
                        str(ingredient.get("value")) if ingredient.get("value") else None
                    ),
                    numerator_unit=concentration[1] if concentration else unit or None,
                    denominator_value=concentration[2] if concentration else None,
                    denominator_unit=concentration[3] if concentration else None,
                    position=index,
                )
            )
        identifiers = [
            MedicationIdentifier(
                medication_id=identity.id,
                identifier_type="drap_registration_id",
                value=registration_id,
                jurisdiction="PK",
                provider="drap_dataset",
            )
        ]
        if record.get("barcode"):
            identifiers.append(
                MedicationIdentifier(
                    medication_id=identity.id,
                    identifier_type="barcode",
                    value=str(record["barcode"]),
                    jurisdiction="PK",
                    provider="drap_dataset",
                )
            )
        identity.identifiers = [
            identifier
            for identifier in identity.identifiers
            if identifier.provider != "drap_dataset"
        ]
        # Delete superseded unique identifiers before inserting replacements.
        self.db.flush()
        identity.identifiers.extend(identifiers)

    @staticmethod
    def _record_hash(record: dict[str, object]) -> str:
        return hashlib.sha256(
            json.dumps(record, sort_keys=True, separators=(",", ":")).encode()
        ).hexdigest()

    @staticmethod
    def _validate_import_record(dataset_type: str, record: dict[str, object]) -> str:
        if dataset_type != "drap_products":
            raise ValueError("unsupported_dataset_type")
        for field in ["registration_id", "brand_name", "generic_name", "ingredients"]:
            if field not in record or record[field] in (None, "", []):
                raise ValueError(f"missing_{field}")
        if not isinstance(record["ingredients"], list):
            raise ValueError("ingredients_must_be_list")
        for field in ["registration_id", "brand_name", "generic_name"]:
            if not isinstance(record[field], str) or not str(record[field]).strip():
                raise ValueError(f"invalid_{field}")
            record[field] = str(record[field]).strip()
        for ingredient in record["ingredients"]:
            if not isinstance(ingredient, dict) or not str(ingredient.get("name") or "").strip():
                raise ValueError("ingredient_name_required")
        return str(record["registration_id"]).strip()

    def audit(
        self,
        actor_id: UUID,
        permissions: list[str],
        action: str,
        target_type: str,
        target_id: str,
        request_id: str,
        metadata: dict[str, object] | None = None,
    ) -> None:
        self.db.add(
            AuditEvent(
                actor_id=actor_id,
                permission_context=permissions,
                action=action,
                target_type=target_type,
                target_id=target_id,
                request_id=request_id,
                safe_metadata=metadata or {},
            )
        )
