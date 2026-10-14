from typing import Annotated

from fastapi import APIRouter, HTTPException, Query
from sqlalchemy import select

from app.api.dependencies import DatabaseDependency, SettingsDependency
from app.core.config import Settings
from app.models import (
    Category,
    ContentSource,
    MedicalAbbreviation,
    MedicalTerm,
    MorphologyElement,
    TermAlias,
    TermDefinition,
    TermMorphology,
    TermRelation,
)
from app.schemas.module2 import (
    AbbreviationRead,
    CategoryRead,
    DefinitionRead,
    MorphologyComponentRead,
    MorphologyRead,
    SearchResponse,
    SearchResultRead,
    SourceRead,
    TermRead,
)
from app.services.terminology import TerminologySearchService, normalize, safe_page_offset

router = APIRouter(tags=["terminology"])

SearchQuery = Annotated[str, Query(min_length=1, max_length=200)]
LanguageQuery = Annotated[str, Query(pattern=r"^[a-z]{2}(?:-[A-Z]{2})?$")]
PageQuery = Annotated[int, Query(ge=1, le=100_000)]
PageSizeQuery = Annotated[int, Query(ge=1, le=100)]


def _source(db: DatabaseDependency, source_id: str) -> SourceRead:
    value = db.get(ContentSource, source_id)
    if value is None:
        raise RuntimeError("Content source missing for a published record")
    return SourceRead(
        provider=value.provider,
        title=value.title,
        identifier=value.identifier,
        canonical_reference=value.canonical_reference,
        version=value.version,
        review_status=value.review_status,
        licensing_attribution=value.licensing_attribution,
    )


def _published_statuses(settings: Settings) -> tuple[str, ...]:
    return ("approved",) if settings.environment == "production" else ("reviewed", "approved")


def _term(
    db: DatabaseDependency,
    term: MedicalTerm,
    published_statuses: tuple[str, ...],
) -> TermRead:
    definitions = db.scalars(
        select(TermDefinition).where(
            TermDefinition.term_id == term.id,
            TermDefinition.review_status.in_(published_statuses),
        )
    ).all()
    aliases = db.scalars(select(TermAlias).where(TermAlias.term_id == term.id)).all()
    abbreviations = db.scalars(
        select(MedicalAbbreviation).where(MedicalAbbreviation.term_id == term.id)
    ).all()
    morphology = db.scalars(
        select(TermMorphology)
        .where(TermMorphology.term_id == term.id)
        .order_by(TermMorphology.position)
    ).all()
    related = db.scalars(select(TermRelation).where(TermRelation.source_term_id == term.id)).all()

    def aliases_of(alias_type: str) -> list[str]:
        return [value.alias for value in aliases if value.alias_type == alias_type]

    return TermRead(
        id=term.id,
        canonical_term=term.canonical_term,
        normalized_term=term.normalized_term,
        pronunciation_text=term.pronunciation_text,
        phonetic_representation=term.phonetic_representation,
        category_id=term.category_id,
        subcategory=term.subcategory,
        language=term.language,
        review_status=term.review_status,
        record_version=term.record_version,
        definitions=[
            DefinitionRead(
                language=value.language,
                source_language=value.source_language,
                translation_method=value.translation_method,
                simple=value.simple_definition,
                standard=value.standard_definition,
                technical=value.technical_definition,
                review_status=value.review_status,
                reviewed_by=value.reviewed_by,
                reviewed_at=value.reviewed_at,
                record_version=value.record_version,
            )
            for value in definitions
        ],
        synonyms=aliases_of("synonym"),
        alternative_spellings=aliases_of("alternative"),
        lay_terms=aliases_of("lay"),
        abbreviations=[value.abbreviation for value in abbreviations],
        related_term_ids=[value.target_term_id for value in related],
        morphology=[
            MorphologyComponentRead(
                element_id=value.element_id,
                surface=value.surface_text,
                meaning=value.meaning,
                start=value.start_offset,
                end=value.end_offset,
                position=value.position,
            )
            for value in morphology
        ],
        examples=term.examples,
        source=_source(db, term.source_id),
    )


@router.get("/terms/search", response_model=SearchResponse)
def search_terms(
    db: DatabaseDependency,
    settings: SettingsDependency,
    q: SearchQuery,
    category: str | None = Query(default=None, max_length=80),
    language: LanguageQuery = "en",
    page: PageQuery = 1,
    page_size: PageSizeQuery = 20,
) -> SearchResponse:
    published_statuses = _published_statuses(settings)
    ranked, ambiguous = TerminologySearchService(db, published_statuses=published_statuses).search(
        q, category=category, language=language
    )
    start = safe_page_offset(page, page_size)
    selected = ranked[start : start + page_size]
    suggested = selected[0].term.canonical_term if selected and selected[0].is_suggestion else None
    resolution_type = (
        "ambiguous" if ambiguous else (selected[0].match_type if selected else "noMatch")
    )
    return SearchResponse(
        original_query=q,
        normalized_query=normalize(q),
        resolution_type=resolution_type,
        ambiguous=ambiguous,
        suggested_query=suggested,
        page=page,
        page_size=page_size,
        total=len(ranked),
        results=[
            SearchResultRead(
                term=_term(db, item.term, published_statuses),
                match_type=item.match_type,
                matched_text=item.matched_text,
                relevance=item.relevance,
                is_suggestion=item.is_suggestion,
            )
            for item in selected
        ],
    )


@router.get("/terms/{term_id}", response_model=TermRead)
def term_detail(
    term_id: str,
    db: DatabaseDependency,
    settings: SettingsDependency,
) -> TermRead:
    term = db.get(MedicalTerm, term_id)
    published_statuses = _published_statuses(settings)
    if term is None or term.deprecated or term.review_status not in published_statuses:
        raise HTTPException(status_code=404, detail="Term not found")
    return _term(db, term, published_statuses)


@router.get("/terms/{term_id}/related", response_model=list[TermRead])
def related_terms(
    term_id: str,
    db: DatabaseDependency,
    settings: SettingsDependency,
) -> list[TermRead]:
    published_statuses = _published_statuses(settings)
    relation_ids = db.scalars(
        select(TermRelation.target_term_id).where(TermRelation.source_term_id == term_id)
    ).all()
    terms = (
        db.scalars(
            select(MedicalTerm).where(
                MedicalTerm.id.in_(relation_ids),
                MedicalTerm.deprecated.is_(False),
                MedicalTerm.review_status.in_(published_statuses),
            )
        ).all()
        if relation_ids
        else []
    )
    return [_term(db, term, published_statuses) for term in terms]


@router.get("/abbreviations", response_model=list[AbbreviationRead])
def abbreviation_list(
    db: DatabaseDependency,
    settings: SettingsDependency,
    q: str = Query(default="", max_length=40),
    limit: int = Query(default=100, ge=1, le=200),
) -> list[AbbreviationRead]:
    statement = (
        select(MedicalAbbreviation)
        .join(MedicalTerm, MedicalTerm.id == MedicalAbbreviation.term_id)
        .where(
            MedicalTerm.deprecated.is_(False),
            MedicalTerm.review_status.in_(_published_statuses(settings)),
        )
        .order_by(MedicalAbbreviation.abbreviation)
        .limit(limit)
    )
    if q:
        statement = statement.where(
            MedicalAbbreviation.normalized_abbreviation.like(f"%{normalize(q)}%")
        )
    return [AbbreviationRead.model_validate(value) for value in db.scalars(statement).all()]


def _morphology_list(
    db: DatabaseDependency,
    published_statuses: tuple[str, ...],
    element_type: str,
    category: str | None,
    language: str,
    limit: int,
) -> list[MorphologyRead]:
    statement = (
        select(MorphologyElement)
        .where(
            MorphologyElement.element_type == element_type,
            MorphologyElement.language == language,
            MorphologyElement.review_status.in_(published_statuses),
        )
        .order_by(MorphologyElement.value)
        .limit(limit)
    )
    if category:
        statement = statement.where(MorphologyElement.category == category)
    return [
        MorphologyRead(
            id=value.id,
            element_type=value.element_type,
            value=value.value,
            meaning=value.meaning,
            explanation=value.explanation,
            examples=value.examples,
            origin=value.origin,
            category=value.category,
            language=value.language,
            pronunciation=value.pronunciation,
            source=_source(db, value.source_id),
        )
        for value in db.scalars(statement).all()
    ]


@router.get("/morphology/prefixes", response_model=list[MorphologyRead])
def prefixes(
    db: DatabaseDependency,
    settings: SettingsDependency,
    category: str | None = Query(default=None, max_length=100),
    language: LanguageQuery = "en",
    limit: int = Query(default=100, ge=1, le=200),
) -> list[MorphologyRead]:
    return _morphology_list(db, _published_statuses(settings), "prefix", category, language, limit)


@router.get("/morphology/roots", response_model=list[MorphologyRead])
def roots(
    db: DatabaseDependency,
    settings: SettingsDependency,
    category: str | None = Query(default=None, max_length=100),
    language: LanguageQuery = "en",
    limit: int = Query(default=100, ge=1, le=200),
) -> list[MorphologyRead]:
    return _morphology_list(db, _published_statuses(settings), "root", category, language, limit)


@router.get("/morphology/suffixes", response_model=list[MorphologyRead])
def suffixes(
    db: DatabaseDependency,
    settings: SettingsDependency,
    category: str | None = Query(default=None, max_length=100),
    language: LanguageQuery = "en",
    limit: int = Query(default=100, ge=1, le=200),
) -> list[MorphologyRead]:
    return _morphology_list(db, _published_statuses(settings), "suffix", category, language, limit)


@router.get("/categories", response_model=list[CategoryRead])
def categories(db: DatabaseDependency) -> list[CategoryRead]:
    values = db.scalars(select(Category).order_by(Category.position, Category.name)).all()
    return [CategoryRead.model_validate(value) for value in values]
