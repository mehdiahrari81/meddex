"""Compile reviewed editorial records into the same offline dataset the mobile app imports."""

import hashlib
from copy import deepcopy
from datetime import UTC, datetime
from typing import Any, cast
from uuid import UUID, uuid4

from sqlalchemy import delete, select, text
from sqlalchemy.orm import Session

from app.core.time import utc_now
from app.models import (
    Category,
    ContentSource,
    ContentVersion,
    Flashcard,
    GovernedContent,
    GovernedContentRevision,
    LearningLesson,
    LessonSection,
    MedicalAbbreviation,
    MedicalTerm,
    MorphologyElement,
    QuizOption,
    QuizQuestion,
    TermAlias,
    TermDefinition,
    TermMorphology,
    TermRelation,
)
from app.services.content_import import ContentImporter
from app.services.terminology import normalize

LIVE_RELEASE_ID = "reference.mobile"
COLLECTIONS = {
    "terminology": "terms",
    "translation": "terms",
    "morphology": "morphology",
    "abbreviation": "abbreviations",
    "lesson": "lessons",
    "flashcard": "flashcards",
    "quiz": "quiz_questions",
}


def publication_lock(db: Session) -> None:
    # Serialize publication across records as well as revisions; no lost releases.
    if db.get_bind().dialect.name == "postgresql":
        db.execute(text("SELECT pg_advisory_xact_lock(427113502)"))


def _iso(value: datetime | None) -> str | None:
    return (
        value.replace(tzinfo=UTC).isoformat()
        if value and value.tzinfo is None
        else (value.isoformat() if value else None)
    )


class ReferencePublicationService:
    def __init__(self, db: Session):
        self.db = db

    def snapshot(self) -> dict[str, Any]:
        """Export canonical reference tables, never user prescriptions or activity."""
        db = self.db

        def rows(model: Any) -> Any:
            return db.scalars(select(model).order_by(model.id)).all()

        sources = [
            {
                "id": r.id,
                "provider": r.provider,
                "source_title": r.title,
                "source_identifier": r.identifier,
                "canonical_reference": r.canonical_reference,
                "locale": r.locale,
                "version": r.version,
                "review_status": r.review_status,
                "content_type": r.content_type,
                "licensing_attribution": r.licensing_attribution,
                "retrieved_at": _iso(r.retrieved_at),
                "source_updated_at": _iso(r.source_updated_at),
            }
            for r in rows(ContentSource)
        ]
        categories = [
            {
                "id": r.id,
                "name": r.name,
                "description": r.description,
                "parent_id": r.parent_id,
                "position": r.position,
            }
            for r in rows(Category)
        ]
        morphology = [
            {
                "id": r.id,
                "type": r.element_type,
                "value": r.value,
                "meaning": r.meaning,
                "explanation": r.explanation,
                "examples": r.examples,
                "origin": r.origin,
                "category": r.category,
                "language": r.language,
                "pronunciation": r.pronunciation,
                "related_element_ids": r.related_element_ids,
                "review_status": r.review_status,
                "source_id": r.source_id,
            }
            for r in rows(MorphologyElement)
        ]
        aliases = list(rows(TermAlias))
        definitions = list(rows(TermDefinition))
        parts = list(rows(TermMorphology))
        relations = db.scalars(select(TermRelation)).all()
        terms = []
        for r in rows(MedicalTerm):
            definition = next(
                (d for d in definitions if d.term_id == r.id and d.language == r.language), None
            )
            if definition is None:
                raise ValueError("Reference term is missing its definition: " + r.id)
            terms.append(
                {
                    "id": r.id,
                    "term": r.canonical_term,
                    "normalized": r.normalized_term,
                    "pronunciation": r.pronunciation_text,
                    "phonetic": r.phonetic_representation,
                    "category_id": r.category_id,
                    "subcategory": r.subcategory,
                    "language": r.language,
                    "review_status": r.review_status,
                    "version": r.record_version,
                    "deprecated": r.deprecated,
                    "replacement_term_id": r.replacement_term_id,
                    "examples": r.examples,
                    "source_id": r.source_id,
                    "definitions": {
                        "simple": definition.simple_definition,
                        "standard": definition.standard_definition,
                        "technical": definition.technical_definition,
                        "source_language": definition.source_language,
                        "translation_method": definition.translation_method,
                        "reviewed_by": definition.reviewed_by,
                        "reviewed_at": _iso(definition.reviewed_at),
                    },
                    **{
                        key: [
                            a.alias for a in aliases if a.term_id == r.id and a.alias_type == kind
                        ]
                        for key, kind in [
                            ("synonyms", "synonym"),
                            ("alternative_spellings", "alternative"),
                            ("lay_terms", "lay"),
                            ("abbreviations", "abbreviation"),
                        ]
                    },
                    "related_term_ids": sorted(
                        v.target_term_id for v in relations if v.source_term_id == r.id
                    ),
                    "morphology": [
                        {
                            "element_id": p.element_id,
                            "type": next(m["type"] for m in morphology if m["id"] == p.element_id),
                            "surface": p.surface_text,
                            "meaning": p.meaning,
                            "start": p.start_offset,
                            "end": p.end_offset,
                        }
                        for p in sorted(parts, key=lambda p: p.position)
                        if p.term_id == r.id
                    ],
                }
            )
        abbreviations = [
            {
                "id": r.id,
                "term_id": r.term_id,
                "abbreviation": r.abbreviation,
                "expansion": r.expansion,
                "context": r.context,
                "category": r.category,
                "ambiguous": r.ambiguous,
                "alternative_meanings": r.alternative_meanings,
                "safety_warning": r.safety_warning,
            }
            for r in rows(MedicalAbbreviation)
        ]
        sections = list(rows(LessonSection))
        lessons = [
            {
                "id": r.id,
                "title": r.title,
                "description": r.description,
                "category_id": r.category_id,
                "difficulty": r.difficulty,
                "estimated_minutes": r.estimated_minutes,
                "objectives": r.objectives,
                "review_question_ids": r.review_question_ids,
                "review_status": r.review_status,
                "version": r.record_version,
                "source_id": r.source_id,
                "sections": [
                    {
                        "id": s.id,
                        "title": s.title,
                        "content": s.content,
                        "type": s.section_type,
                        "position": s.position,
                        "linked_term_ids": s.linked_term_ids,
                    }
                    for s in sorted(sections, key=lambda s: s.position)
                    if s.lesson_id == r.id
                ],
            }
            for r in rows(LearningLesson)
        ]
        flashcards = [
            {
                "id": r.id,
                "type": r.card_type,
                "front": r.front,
                "back": r.back,
                "category_id": r.category_id,
                "difficulty": r.difficulty,
                "linked_content_id": r.linked_content_id,
                "source_id": r.source_id,
            }
            for r in rows(Flashcard)
        ]
        options = list(rows(QuizOption))
        quizzes = [
            {
                "id": r.id,
                "type": r.question_type,
                "prompt": r.prompt,
                "explanation": r.explanation,
                "category_id": r.category_id,
                "difficulty": r.difficulty,
                "linked_term_id": r.linked_term_id,
                "source_id": r.source_id,
                "options": [
                    {"id": o.id, "text": o.option_text, "correct": o.is_correct}
                    for o in sorted(options, key=lambda o: o.position)
                    if o.question_id == r.id
                ],
            }
            for r in rows(QuizQuestion)
        ]
        document = {
            "schema_version": 1,
            "dataset_name": "mediexplain-reference",
            "dataset_version": "publication-" + uuid4().hex[:20],
            "generated_at": utc_now().isoformat(),
            "production_approved": bool(sources)
            and all(s["review_status"] == "approved" for s in sources),
            "sources": sources,
            "categories": categories,
            "morphology": morphology,
            "terms": terms,
            "abbreviations": abbreviations,
            "lessons": lessons,
            "flashcards": flashcards,
            "quiz_questions": quizzes,
        }
        withdrawn = [
            str(r.content["id"])
            for r in db.scalars(
                select(GovernedContentRevision)
                .join(
                    GovernedContent, GovernedContent.stable_id == GovernedContentRevision.stable_id
                )
                .where(
                    GovernedContent.content_type == "abbreviation",
                    GovernedContent.lifecycle_state.in_(["deprecated", "archived"]),
                    GovernedContent.current_revision == GovernedContentRevision.revision,
                )
            )
            if r.content.get("id")
        ]
        document["withdrawn_abbreviation_ids"] = withdrawn
        local_reviews = db.scalars(
            select(GovernedContentRevision)
            .join(GovernedContent, GovernedContent.stable_id == GovernedContentRevision.stable_id)
            .where(GovernedContent.published_revision == GovernedContentRevision.revision)
        )
        if any(r.source_metadata.get("local_self_review") for r in local_reviews):
            document["production_approved"] = False
        ContentImporter(db).validate(document)
        return document

    def candidate(self, content_type: str, content: dict[str, Any]) -> dict[str, Any]:
        collection = COLLECTIONS.get(content_type)
        if collection is None:
            raise ValueError("Unsupported mobile reference content type")
        document = self.snapshot()
        item = deepcopy(content)
        item_id = item.get("id")
        if not isinstance(item_id, str) or not 1 <= len(item_id) <= 100:
            raise ValueError("Content requires an id of 1-100 characters")
        values = document[collection]
        previous = next((v for v in values if v["id"] == item_id), None)
        if content_type in {"terminology", "translation"}:
            item["normalized"] = normalize(str(item.get("term", "")))
        if "review_status" in item:
            item["review_status"] = "approved"
        for key in ("objectives", "examples"):
            if isinstance(item.get(key), list) and all(isinstance(v, str) for v in item[key]):
                item[key] = [v.strip() for v in item[key] if v.strip()]
        if content_type == "lesson":
            if not item.get("sections") or not item.get("objectives"):
                raise ValueError("A lesson needs at least one objective and one section")
            minutes = item.get("estimated_minutes")
            if not isinstance(minutes, int) or not 1 <= minutes <= 180:
                raise ValueError("Lesson duration must be between 1 and 180 minutes")
            section_ids = [v.get("id") for v in item["sections"] if isinstance(v, dict)]
            if len(section_ids) != len(set(section_ids)):
                raise ValueError("Lesson section IDs must be unique")
            if any(not isinstance(v, str) or not 1 <= len(v) <= 120 for v in section_ids):
                raise ValueError("Lesson section IDs must contain 1-120 characters")
            collisions = self.db.scalars(
                select(LessonSection).where(
                    LessonSection.id.in_(section_ids), LessonSection.lesson_id != item_id
                )
            ).all()
            if collisions:
                raise ValueError("A section ID already belongs to another lesson")
        if "version" in item:
            item["version"] = (previous.get("version", 0) if previous else 0) + 1
        document[collection] = [v for v in values if v["id"] != item_id] + [item]
        ContentImporter(self.db).validate(document)
        source_id = item.get("source_id")
        if content_type == "abbreviation":
            parent = next(t for t in document["terms"] if t["id"] == item["term_id"])
            if parent.get("deprecated"):
                raise ValueError("An abbreviation must refer to an active term")
            source_id = parent["source_id"]
        source = next((s for s in document["sources"] if s["id"] == source_id), None)
        if source is None or source["review_status"] not in {"reviewed", "approved"}:
            raise ValueError("Choose an existing reviewed or approved reference source")
        morphology_keys = [
            (v["type"], normalize(v["value"]).replace(" ", "").replace("-", ""), v["language"])
            for v in document["morphology"]
        ]
        if len(morphology_keys) != len(set(morphology_keys)):
            raise ValueError("A word part with this type, value and language already exists")
        # Do not let an editor turn a source-backed identity into another content ID.
        return document

    def publish_item(self, content_type: str, content: dict[str, Any]) -> None:
        document = self.candidate(content_type, content)
        # Import only the changed collection, but validate against the complete graph.
        importer = ContentImporter(self.db)
        collection = COLLECTIONS[content_type]
        patch = {**document, **{key: [] for key in COLLECTIONS.values()}}
        item_id = content["id"]
        patch[collection] = [v for v in document[collection] if v["id"] == item_id]
        if collection == "terms":
            existing = self.db.get(MedicalTerm, str(item_id))
            created_at = existing.created_at if existing else None
            importer._terms(patch)
            if created_at is not None:
                term = self.db.get(MedicalTerm, str(item_id))
                assert term is not None
                term.created_at = created_at
        elif collection == "morphology":
            importer._morphology(patch)
        elif collection == "abbreviations":
            previous_abbreviation = self.db.get(MedicalAbbreviation, str(item_id))
            old_term = previous_abbreviation.term_id if previous_abbreviation else None
            old_value = previous_abbreviation.abbreviation if previous_abbreviation else None
            importer._abbreviations(patch)
            self.db.flush()
            if old_term and old_value:
                self._remove_abbreviation_alias(old_term, old_value)
            abbreviation = self.db.get(MedicalAbbreviation, str(item_id))
            assert abbreviation is not None
            parent = self.db.get(MedicalTerm, abbreviation.term_id)
            assert parent is not None
            key = "admin-abbreviation:" + hashlib.sha256(str(item_id).encode()).hexdigest()[:24]
            self.db.merge(
                TermAlias(
                    id=key,
                    term_id=abbreviation.term_id,
                    alias=abbreviation.abbreviation,
                    normalized_alias=normalize(abbreviation.abbreviation),
                    alias_type="abbreviation",
                    language=parent.language,
                )
            )
        else:
            importer._learning(patch)
        self.db.flush()

    def _remove_abbreviation_alias(self, term_id: str, value: str) -> None:
        remaining = self.db.scalar(
            select(MedicalAbbreviation).where(
                MedicalAbbreviation.term_id == term_id,
                MedicalAbbreviation.normalized_abbreviation == normalize(value),
            )
        )
        if remaining is None:
            self.db.execute(
                delete(TermAlias).where(
                    TermAlias.term_id == term_id,
                    TermAlias.alias_type == "abbreviation",
                    TermAlias.normalized_alias == normalize(value),
                )
            )

    def withdraw_item(self, content_type: str, content: dict[str, Any]) -> None:
        item_id = str(content["id"])
        if content_type in {"terminology", "translation", "morphology", "lesson"}:
            model = {
                "terminology": MedicalTerm,
                "translation": MedicalTerm,
                "morphology": MorphologyElement,
                "lesson": LearningLesson,
            }[content_type]
            row = cast(
                MedicalTerm | MorphologyElement | LearningLesson | None, self.db.get(model, item_id)
            )
            if row is not None:
                row.review_status = "deprecated"
                if isinstance(row, MedicalTerm):
                    row.deprecated = True
        elif content_type == "abbreviation":
            abbreviation = self.db.get(MedicalAbbreviation, item_id)
            if abbreviation is not None:
                term_id, value = abbreviation.term_id, abbreviation.abbreviation
                self.db.delete(abbreviation)
                self.db.flush()
                self._remove_abbreviation_alias(term_id, value)
        elif content_type in {"flashcard", "quiz"}:
            # Keep IDs/progress/history; the existing source visibility filter hides it.
            entity = (
                self.db.get(Flashcard, item_id)
                if content_type == "flashcard"
                else self.db.get(QuizQuestion, item_id)
            )
            if entity is not None:
                original = self.db.get(ContentSource, entity.source_id)
                assert original is not None
                suffix = hashlib.sha256((content_type + item_id).encode()).hexdigest()[:24]
                source_id = "withdrawn-" + suffix
                if self.db.get(ContentSource, source_id) is None:
                    self.db.add(
                        ContentSource(
                            id=source_id,
                            provider=original.provider,
                            title=original.title,
                            identifier="withdrawn-" + suffix,
                            canonical_reference=original.canonical_reference,
                            locale=original.locale,
                            version=original.version,
                            review_status="deprecated",
                            content_type=original.content_type,
                            licensing_attribution=original.licensing_attribution,
                            retrieved_at=original.retrieved_at,
                            source_updated_at=original.source_updated_at,
                        )
                    )
                    self.db.flush()
                entity.source_id = source_id
        else:
            raise ValueError("Withdraw individual reference records, not an entire dataset")
        self.db.flush()

    def compile_release(self, actor_id: UUID, reason: str) -> dict[str, Any]:
        document = self.snapshot()
        now = utc_now()
        record = self.db.get(GovernedContent, LIVE_RELEASE_ID)
        if record is None:
            record = GovernedContent(
                stable_id=LIVE_RELEASE_ID,
                content_type="dataset",
                lifecycle_state="published",
                current_revision=0,
            )
            self.db.add(record)
            self.db.flush()
        record.current_revision += 1
        record.published_revision = record.current_revision
        record.lifecycle_state = "published"
        record.updated_at = now
        self.db.add(
            GovernedContentRevision(
                stable_id=LIVE_RELEASE_ID,
                revision=record.current_revision,
                content=document,
                source_metadata={
                    "origin": "compiled_canonical_reference_tables",
                    "note": (
                        "Compiled from published or previously installed reference records; "
                        "source attribution is preserved."
                    ),
                },
                author_id=actor_id,
                change_reason=reason[:1000],
                review_state="published",
                published_at=now,
            )
        )
        self.db.merge(
            ContentVersion(
                dataset_name=document["dataset_name"],
                dataset_version=document["dataset_version"],
                production_approved=document["production_approved"],
                installed_at=now,
                updated_at=now,
            )
        )
        self.db.flush()
        return document

    def register_existing(self, actor_id: UUID) -> int:
        """One-time, idempotent catalogue registration, preserving provenance and content."""
        publication_lock(self.db)
        document = self.snapshot()
        sources = {s["id"]: s for s in document["sources"]}
        terms = {t["id"]: t for t in document["terms"]}
        count = 0
        for content_type, collection in COLLECTIONS.items():
            if content_type == "translation":
                continue
            for item in document[collection]:
                stable_id = content_type + "." + item["id"]
                if self.db.get(GovernedContent, stable_id) is not None:
                    continue
                source_id = item.get("source_id") or terms.get(item.get("term_id"), {}).get(
                    "source_id"
                )
                source = sources.get(source_id, {})
                published = item.get("review_status", "reviewed") in {
                    "reviewed",
                    "approved",
                } and source.get("review_status") in {"reviewed", "approved"}
                state = "published" if published else "draft"
                self.db.add(
                    GovernedContent(
                        stable_id=stable_id,
                        content_type=content_type,
                        lifecycle_state=state,
                        current_revision=1,
                        published_revision=1 if published else None,
                    )
                )
                self.db.flush()
                self.db.add(
                    GovernedContentRevision(
                        stable_id=stable_id,
                        revision=1,
                        content=item,
                        source_metadata={
                            "origin": "existing_installed_reference",
                            "source": source,
                            "note": "Registered existing content, not a new clinical review.",
                        },
                        author_id=actor_id,
                        change_reason="Register existing reference content for administration",
                        review_state=state,
                        published_at=utc_now() if published else None,
                    )
                )
                count += 1
        if self.db.get(GovernedContent, LIVE_RELEASE_ID) is None:
            self.compile_release(actor_id, "Register the existing mobile reference catalogue")
        self.db.flush()
        return count
