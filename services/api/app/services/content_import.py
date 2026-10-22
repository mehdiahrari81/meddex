import json
import re
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any

from sqlalchemy import delete
from sqlalchemy.orm import Session

from app.models import (
    Category,
    ContentSource,
    ContentVersion,
    Flashcard,
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
from app.services.terminology import normalize


@dataclass(frozen=True)
class ImportReport:
    dataset_name: str
    dataset_version: str
    changed: bool
    production_approved: bool
    terms: int
    morphology_elements: int
    abbreviations: int
    lessons: int
    flashcards: int
    quiz_questions: int


class DatasetValidationError(ValueError):
    pass


class ContentImporter:
    def __init__(self, db: Session) -> None:
        self.db = db

    def import_path(
        self, path: Path, *, dry_run: bool = False, additive: bool = False
    ) -> ImportReport:
        try:
            raw = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            raise DatasetValidationError(f"Cannot read terminology dataset: {error}") from error
        return self.import_document(raw, dry_run=dry_run, additive=additive)

    def import_document(
        self, raw: Any, *, dry_run: bool = False, commit: bool = True, additive: bool = False
    ) -> ImportReport:
        document = self.validate(raw)
        dataset_name = _string(document, "dataset_name")
        dataset_version = _string(document, "dataset_version")
        current = self.db.get(ContentVersion, dataset_name)
        report = ImportReport(
            dataset_name=dataset_name,
            dataset_version=dataset_version,
            changed=current is None or current.dataset_version != dataset_version,
            production_approved=_boolean(document, "production_approved"),
            terms=len(_list(document, "terms")),
            morphology_elements=len(_list(document, "morphology")),
            abbreviations=len(_list(document, "abbreviations")),
            lessons=len(_list(document, "lessons")),
            flashcards=len(_list(document, "flashcards")),
            quiz_questions=len(_list(document, "quiz_questions")),
        )
        if dry_run or not report.changed:
            return report
        with self.db.begin_nested():
            self._sources(document, additive=additive)
            self._categories(document, additive=additive)
            self._morphology(document)
            self._terms(document)
            self._abbreviations(document)
            self._learning(document, additive=additive)
            generated_at = _datetime(document, "generated_at")
            self.db.merge(
                ContentVersion(
                    dataset_name=dataset_name,
                    dataset_version=dataset_version,
                    production_approved=report.production_approved,
                    installed_at=datetime.now().astimezone(),
                    updated_at=generated_at,
                )
            )
        if commit:
            self.db.commit()
        else:
            self.db.flush()
        return report

    def validate(self, raw: Any) -> dict[str, Any]:
        if not isinstance(raw, dict):
            raise DatasetValidationError("Dataset root must be an object")
        document: dict[str, Any] = raw
        if document.get("schema_version") != 1:
            raise DatasetValidationError("Unsupported dataset schema version")
        required = (
            "dataset_name",
            "dataset_version",
            "production_approved",
            "generated_at",
            "sources",
            "categories",
            "morphology",
            "terms",
            "abbreviations",
            "lessons",
            "flashcards",
            "quiz_questions",
        )
        for key in required:
            if key not in document:
                raise DatasetValidationError(f"Missing dataset field: {key}")
        _string(document, "dataset_name")
        _string(document, "dataset_version")
        _boolean(document, "production_approved")
        _datetime(document, "generated_at")

        def unique_ids(collection: str) -> set[str]:
            result: set[str] = set()
            for value in _list(document, collection):
                item_id = _string(_object(value), "id")
                if item_id in result:
                    raise DatasetValidationError(f"Duplicate {collection} ID: {item_id}")
                result.add(item_id)
            return result

        source_ids = unique_ids("sources")
        category_ids = unique_ids("categories")
        morphology_ids = unique_ids("morphology")
        term_ids = unique_ids("terms")
        unique_ids("abbreviations")
        unique_ids("lessons")
        unique_ids("flashcards")
        question_ids = unique_ids("quiz_questions")
        review_statuses = {"draft", "reviewed", "approved", "deprecated"}
        difficulties = {"beginner", "intermediate", "advanced"}

        def review_status(value: dict[str, Any]) -> str:
            status = _string(value, "review_status")
            if status not in review_statuses:
                raise DatasetValidationError(f"Invalid review status: {status}")
            return status

        for raw_source in _list(document, "sources"):
            source = _object(raw_source)
            _string(source, "provider")
            _string(source, "source_title")
            _string(source, "source_identifier")
            _optional_string(source, "canonical_reference")
            _string(source, "locale")
            _string(source, "version")
            _string(source, "content_type")
            _optional_string(source, "licensing_attribution")
            _datetime(source, "retrieved_at")
            _optional_datetime(source, "source_updated_at")
            review_status(source)
        for raw_category in _list(document, "categories"):
            category = _object(raw_category)
            _string(category, "name")
            _string(category, "description")
            _integer(category, "position")
            parent_id = _optional_string(category, "parent_id")
            if parent_id and parent_id not in category_ids:
                raise DatasetValidationError(f"Unknown parent category: {parent_id}")
        for raw_morphology in _list(document, "morphology"):
            morphology = _object(raw_morphology)
            if _string(morphology, "type") not in {"prefix", "root", "suffix"}:
                raise DatasetValidationError(
                    f"Invalid morphology type: {_string(morphology, 'type')}"
                )
            _string(morphology, "value")
            _string(morphology, "meaning")
            _string(morphology, "explanation")
            _strings(morphology, "examples")
            _optional_string(morphology, "origin")
            _string(morphology, "category")
            _string(morphology, "language")
            _optional_string(morphology, "pronunciation")
            _optional_strings(morphology, "related_element_ids")
            review_status(morphology)
        normalized_terms: set[tuple[str, str]] = set()
        for raw_term in _list(document, "terms"):
            term = _object(raw_term)
            term_id = _string(term, "id")
            language = _string(term, "language")
            normalized_term = normalize(_string(term, "normalized"))
            if not normalized_term:
                raise DatasetValidationError(f"Term {term_id} has an empty normalized key")
            if (normalized_term, language) in normalized_terms:
                raise DatasetValidationError(f"Duplicate normalized term: {normalized_term}")
            normalized_terms.add((normalized_term, language))
            if _string(term, "category_id") not in category_ids:
                raise DatasetValidationError(f"Unknown category for term: {term_id}")
            if _string(term, "source_id") not in source_ids:
                raise DatasetValidationError(f"Unknown source for term: {term_id}")
            definitions = _object(term.get("definitions"))
            _string(definitions, "simple")
            _string(definitions, "standard")
            _string(definitions, "technical")
            _optional_string(definitions, "source_language")
            _optional_string(definitions, "translation_method")
            _optional_string(definitions, "reviewed_by")
            _optional_datetime(definitions, "reviewed_at")
            _optional_string(term, "pronunciation")
            _optional_string(term, "phonetic")
            _optional_string(term, "subcategory")
            _integer(term, "version")
            _optional_boolean(term, "deprecated", False)
            _optional_string(term, "replacement_term_id")
            _strings(term, "synonyms")
            _strings(term, "alternative_spellings")
            _strings(term, "lay_terms")
            _strings(term, "abbreviations")
            _strings(term, "examples")
            review_status(term)
            for relation in _list(term, "related_term_ids"):
                if relation not in term_ids:
                    raise DatasetValidationError(f"Unknown related term: {relation}")
            for component in _list(term, "morphology"):
                part = _object(component)
                element_id = _string(part, "element_id")
                if element_id not in morphology_ids:
                    raise DatasetValidationError(f"Unknown morphology element: {element_id}")
                if _string(part, "type") not in {"prefix", "root", "suffix"}:
                    raise DatasetValidationError("Invalid term morphology type")
                _string(part, "surface")
                _string(part, "meaning")
                _integer(part, "start")
                _integer(part, "end")
        for abbreviation in _list(document, "abbreviations"):
            value = _object(abbreviation)
            term_id = _string(value, "term_id")
            if term_id not in term_ids:
                raise DatasetValidationError(f"Unknown abbreviation term: {term_id}")
            _string(value, "abbreviation")
            _string(value, "expansion")
            _string(value, "context")
            _string(value, "category")
            _boolean(value, "ambiguous")
            _strings(value, "alternative_meanings")
            _optional_string(value, "safety_warning")
        for raw_morphology in _list(document, "morphology"):
            value = _object(raw_morphology)
            if _string(value, "source_id") not in source_ids:
                raise DatasetValidationError(f"Unknown morphology source: {_string(value, 'id')}")
        for raw_lesson in _list(document, "lessons"):
            lesson = _object(raw_lesson)
            if _string(lesson, "source_id") not in source_ids:
                raise DatasetValidationError(f"Unknown lesson source: {_string(lesson, 'id')}")
            _string(lesson, "title")
            _string(lesson, "description")
            if _string(lesson, "category_id") not in category_ids:
                raise DatasetValidationError(
                    f"Unknown lesson category: {_string(lesson, 'category_id')}"
                )
            if _string(lesson, "difficulty") not in difficulties:
                raise DatasetValidationError(
                    f"Invalid lesson difficulty: {_string(lesson, 'difficulty')}"
                )
            _integer(lesson, "estimated_minutes")
            _strings(lesson, "objectives")
            _integer(lesson, "version")
            review_status(lesson)
            for question_id in _strings(lesson, "review_question_ids"):
                if question_id not in question_ids:
                    raise DatasetValidationError(f"Unknown review question: {question_id}")
            for raw_section in _list(lesson, "sections"):
                section = _object(raw_section)
                _string(section, "id")
                _string(section, "title")
                _string(section, "content")
                _string(section, "type")
                _integer(section, "position")
                for term_id in _strings(section, "linked_term_ids"):
                    if term_id not in term_ids:
                        raise DatasetValidationError(f"Unknown lesson term: {term_id}")
        for raw_flashcard in _list(document, "flashcards"):
            flashcard = _object(raw_flashcard)
            if _string(flashcard, "source_id") not in source_ids:
                raise DatasetValidationError(
                    f"Unknown flashcard source: {_string(flashcard, 'id')}"
                )
            _string(flashcard, "type")
            _string(flashcard, "front")
            _string(flashcard, "back")
            if _string(flashcard, "category_id") not in category_ids:
                raise DatasetValidationError(
                    f"Unknown flashcard category: {_string(flashcard, 'category_id')}"
                )
            if _string(flashcard, "difficulty") not in difficulties:
                raise DatasetValidationError(
                    f"Invalid flashcard difficulty: {_string(flashcard, 'difficulty')}"
                )
            linked_id = _optional_string(flashcard, "linked_content_id")
            if linked_id and linked_id not in term_ids and linked_id not in morphology_ids:
                raise DatasetValidationError(f"Unknown flashcard content: {linked_id}")
        for raw_question in _list(document, "quiz_questions"):
            question = _object(raw_question)
            if _string(question, "source_id") not in source_ids:
                raise DatasetValidationError(f"Unknown quiz source: {_string(question, 'id')}")
            _string(question, "type")
            _string(question, "prompt")
            _string(question, "explanation")
            if _string(question, "category_id") not in category_ids:
                raise DatasetValidationError(
                    f"Unknown quiz category: {_string(question, 'category_id')}"
                )
            if _string(question, "difficulty") not in difficulties:
                raise DatasetValidationError(
                    f"Invalid quiz difficulty: {_string(question, 'difficulty')}"
                )
            linked_term_id = _optional_string(question, "linked_term_id")
            if linked_term_id and linked_term_id not in term_ids:
                raise DatasetValidationError(f"Unknown quiz term: {linked_term_id}")
            options = [_object(value) for value in _list(question, "options")]
            option_ids: set[str] = set()
            for option in options:
                option_id = _string(option, "id")
                if option_id in option_ids:
                    raise DatasetValidationError(f"Duplicate quiz option ID: {option_id}")
                option_ids.add(option_id)
                _string(option, "text")
                _boolean(option, "correct")
            if len(options) < 2 or sum(_boolean(value, "correct") for value in options) != 1:
                raise DatasetValidationError(
                    f"Quiz {_string(question, 'id')} must have at least two options "
                    "and exactly one correct answer"
                )
        return document

    def _sources(self, document: dict[str, Any], *, additive: bool = False) -> None:
        for raw in _list(document, "sources"):
            value = _object(raw)
            if additive and self.db.get(ContentSource, _string(value, "id")) is not None:
                continue
            self.db.merge(
                ContentSource(
                    id=_string(value, "id"),
                    provider=_string(value, "provider"),
                    title=_string(value, "source_title"),
                    identifier=_string(value, "source_identifier"),
                    canonical_reference=_optional_string(value, "canonical_reference"),
                    locale=_string(value, "locale"),
                    version=_string(value, "version"),
                    review_status=_string(value, "review_status"),
                    content_type=_string(value, "content_type"),
                    licensing_attribution=_optional_string(value, "licensing_attribution"),
                    retrieved_at=_datetime(value, "retrieved_at"),
                    source_updated_at=_optional_datetime(value, "source_updated_at"),
                )
            )

    def _categories(self, document: dict[str, Any], *, additive: bool = False) -> None:
        for raw in _list(document, "categories"):
            value = _object(raw)
            if additive and self.db.get(Category, _string(value, "id")) is not None:
                continue
            self.db.merge(
                Category(
                    id=_string(value, "id"),
                    name=_string(value, "name"),
                    description=_string(value, "description"),
                    parent_id=_optional_string(value, "parent_id"),
                    position=_integer(value, "position"),
                )
            )

    def _morphology(self, document: dict[str, Any]) -> None:
        for raw in _list(document, "morphology"):
            value = _object(raw)
            self.db.merge(
                MorphologyElement(
                    id=_string(value, "id"),
                    element_type=_string(value, "type"),
                    value=_string(value, "value"),
                    normalized_value=re.sub(r"[\s-]", "", normalize(_string(value, "value"))),
                    meaning=_string(value, "meaning"),
                    explanation=_string(value, "explanation"),
                    examples=_strings(value, "examples"),
                    origin=_optional_string(value, "origin"),
                    category=_string(value, "category"),
                    language=_string(value, "language"),
                    pronunciation=_optional_string(value, "pronunciation"),
                    related_element_ids=_optional_strings(value, "related_element_ids"),
                    review_status=_string(value, "review_status"),
                    source_id=_string(value, "source_id"),
                )
            )

    def _terms(self, document: dict[str, Any]) -> None:
        timestamp = _datetime(document, "generated_at")
        values = [_object(item) for item in _list(document, "terms")]
        for value in values:
            term_id = _string(value, "id")
            self.db.merge(
                MedicalTerm(
                    id=term_id,
                    canonical_term=_string(value, "term"),
                    normalized_term=normalize(_string(value, "normalized")),
                    pronunciation_text=_optional_string(value, "pronunciation"),
                    phonetic_representation=_optional_string(value, "phonetic"),
                    category_id=_string(value, "category_id"),
                    subcategory=_optional_string(value, "subcategory"),
                    language=_string(value, "language"),
                    review_status=_string(value, "review_status"),
                    record_version=_integer(value, "version"),
                    deprecated=_optional_boolean(value, "deprecated", False),
                    replacement_term_id=_optional_string(value, "replacement_term_id"),
                    source_id=_string(value, "source_id"),
                    examples=_strings(value, "examples"),
                    created_at=timestamp,
                    updated_at=timestamp,
                )
            )
        self.db.flush()
        for value in values:
            term_id = _string(value, "id")
            self.db.execute(delete(TermAlias).where(TermAlias.term_id == term_id))
            self.db.execute(delete(TermMorphology).where(TermMorphology.term_id == term_id))
            self.db.execute(delete(TermRelation).where(TermRelation.source_term_id == term_id))
            definitions = _object(value.get("definitions"))
            language = _string(value, "language")
            source_language = _optional_string(definitions, "source_language") or language
            language = _string(value, "language")
            self.db.merge(
                TermDefinition(
                    id=f"{term_id}:{language}",
                    term_id=term_id,
                    language=language,
                    source_language=source_language,
                    translation_method=_optional_string(definitions, "translation_method")
                    or ("original" if language == source_language else None),
                    simple_definition=_string(definitions, "simple"),
                    standard_definition=_string(definitions, "standard"),
                    technical_definition=_string(definitions, "technical"),
                    review_status=_string(value, "review_status"),
                    reviewed_by=_optional_string(definitions, "reviewed_by"),
                    reviewed_at=_optional_datetime(definitions, "reviewed_at"),
                    record_version=_integer(value, "version"),
                )
            )
            position = 0
            for alias_type, key in (
                ("synonym", "synonyms"),
                ("alternative", "alternative_spellings"),
                ("lay", "lay_terms"),
                ("abbreviation", "abbreviations"),
            ):
                for alias in _strings(value, key):
                    self.db.add(
                        TermAlias(
                            id=f"{term_id}:{alias_type}:{position}",
                            term_id=term_id,
                            alias=alias,
                            normalized_alias=normalize(alias),
                            alias_type=alias_type,
                            language=_string(value, "language"),
                        )
                    )
                    position += 1
            for position, raw_component in enumerate(_list(value, "morphology")):
                component = _object(raw_component)
                self.db.add(
                    TermMorphology(
                        id=f"{term_id}:morphology:{position}",
                        term_id=term_id,
                        element_id=_string(component, "element_id"),
                        surface_text=_string(component, "surface"),
                        meaning=_string(component, "meaning"),
                        start_offset=_integer(component, "start"),
                        end_offset=_integer(component, "end"),
                        position=position,
                    )
                )
            for related_id in _strings(value, "related_term_ids"):
                self.db.add(
                    TermRelation(
                        source_term_id=term_id,
                        target_term_id=related_id,
                        relation_type="related",
                    )
                )

    def _abbreviations(self, document: dict[str, Any]) -> None:
        ids = [_string(_object(item), "id") for item in _list(document, "abbreviations")]
        if ids:
            self.db.execute(delete(MedicalAbbreviation).where(MedicalAbbreviation.id.in_(ids)))
        for raw in _list(document, "abbreviations"):
            value = _object(raw)
            self.db.add(
                MedicalAbbreviation(
                    id=_string(value, "id"),
                    term_id=_string(value, "term_id"),
                    abbreviation=_string(value, "abbreviation"),
                    normalized_abbreviation=normalize(_string(value, "abbreviation")),
                    expansion=_string(value, "expansion"),
                    context=_string(value, "context"),
                    category=_string(value, "category"),
                    ambiguous=_boolean(value, "ambiguous"),
                    alternative_meanings=_strings(value, "alternative_meanings"),
                    safety_warning=_optional_string(value, "safety_warning"),
                )
            )

    def _learning(self, document: dict[str, Any], *, additive: bool = False) -> None:
        for raw in _list(document, "lessons"):
            value = _object(raw)
            if additive and self.db.get(LearningLesson, _string(value, "id")) is not None:
                continue
            lesson_id = _string(value, "id")
            self.db.merge(
                LearningLesson(
                    id=lesson_id,
                    title=_string(value, "title"),
                    description=_string(value, "description"),
                    category_id=_string(value, "category_id"),
                    difficulty=_string(value, "difficulty"),
                    estimated_minutes=_integer(value, "estimated_minutes"),
                    objectives=_strings(value, "objectives"),
                    review_question_ids=_strings(value, "review_question_ids"),
                    review_status=_string(value, "review_status"),
                    record_version=_integer(value, "version"),
                    source_id=_string(value, "source_id"),
                )
            )
            self.db.execute(delete(LessonSection).where(LessonSection.lesson_id == lesson_id))
            for raw_section in _list(value, "sections"):
                section = _object(raw_section)
                self.db.add(
                    LessonSection(
                        id=_string(section, "id"),
                        lesson_id=lesson_id,
                        title=_string(section, "title"),
                        content=_string(section, "content"),
                        section_type=_string(section, "type"),
                        position=_integer(section, "position"),
                        linked_term_ids=_strings(section, "linked_term_ids"),
                    )
                )
        for raw in _list(document, "flashcards"):
            value = _object(raw)
            if additive and self.db.get(Flashcard, _string(value, "id")) is not None:
                continue
            self.db.merge(
                Flashcard(
                    id=_string(value, "id"),
                    card_type=_string(value, "type"),
                    front=_string(value, "front"),
                    back=_string(value, "back"),
                    category_id=_string(value, "category_id"),
                    difficulty=_string(value, "difficulty"),
                    linked_content_id=_optional_string(value, "linked_content_id"),
                    source_id=_string(value, "source_id"),
                )
            )
        for raw in _list(document, "quiz_questions"):
            value = _object(raw)
            question_id = _string(value, "id")
            self.db.merge(
                QuizQuestion(
                    id=question_id,
                    question_type=_string(value, "type"),
                    prompt=_string(value, "prompt"),
                    explanation=_string(value, "explanation"),
                    category_id=_string(value, "category_id"),
                    difficulty=_string(value, "difficulty"),
                    linked_term_id=_optional_string(value, "linked_term_id"),
                    source_id=_string(value, "source_id"),
                )
            )
            # Options are inserted without ORM relationships. Persist a newly
            # created parent first, including when the session disables autoflush.
            self.db.flush()
            self.db.execute(delete(QuizOption).where(QuizOption.question_id == question_id))
            for position, raw_option in enumerate(_list(value, "options")):
                option = _object(raw_option)
                self.db.add(
                    QuizOption(
                        id=_string(option, "id"),
                        question_id=question_id,
                        option_text=_string(option, "text"),
                        is_correct=_boolean(option, "correct"),
                        position=position,
                    )
                )


def _object(value: Any) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise DatasetValidationError("Expected an object")
    return value


def _list(value: dict[str, Any], key: str) -> list[Any]:
    result = value.get(key)
    if not isinstance(result, list):
        raise DatasetValidationError(f"{key} must be a list")
    return result


def _string(value: dict[str, Any], key: str) -> str:
    result = value.get(key)
    if not isinstance(result, str) or not result.strip():
        raise DatasetValidationError(f"{key} must be a non-empty string")
    return result


def _optional_string(value: dict[str, Any], key: str) -> str | None:
    result = value.get(key)
    if result is None:
        return None
    if not isinstance(result, str):
        raise DatasetValidationError(f"{key} must be a string or null")
    return result


def _integer(value: dict[str, Any], key: str) -> int:
    result = value.get(key)
    if not isinstance(result, int):
        raise DatasetValidationError(f"{key} must be an integer")
    return result


def _boolean(value: dict[str, Any], key: str) -> bool:
    result = value.get(key)
    if not isinstance(result, bool):
        raise DatasetValidationError(f"{key} must be a boolean")
    return result


def _optional_boolean(value: dict[str, Any], key: str, default: bool) -> bool:
    result = value.get(key, default)
    if not isinstance(result, bool):
        raise DatasetValidationError(f"{key} must be a boolean")
    return result


def _strings(value: dict[str, Any], key: str) -> list[str]:
    result = _list(value, key)
    if not all(isinstance(item, str) for item in result):
        raise DatasetValidationError(f"{key} must contain strings")
    return result


def _optional_strings(value: dict[str, Any], key: str) -> list[str]:
    if key not in value:
        return []
    return _strings(value, key)


def _datetime(value: dict[str, Any], key: str) -> datetime:
    try:
        return datetime.fromisoformat(_string(value, key).replace("Z", "+00:00"))
    except ValueError as error:
        raise DatasetValidationError(f"{key} must be ISO-8601") from error


def _optional_datetime(value: dict[str, Any], key: str) -> datetime | None:
    raw = _optional_string(value, key)
    if raw is None:
        return None
    try:
        return datetime.fromisoformat(raw.replace("Z", "+00:00"))
    except ValueError as error:
        raise DatasetValidationError(f"{key} must be ISO-8601") from error
