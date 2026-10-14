from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import Field, field_validator

from app.schemas.common import StrictSchema

ReviewStatus = Literal["draft", "reviewed", "approved", "deprecated"]
Difficulty = Literal["beginner", "intermediate", "advanced"]
ContentType = Literal["term", "abbreviation", "prefix", "root", "suffix"]


class SourceRead(StrictSchema):
    provider: str
    title: str
    identifier: str
    canonical_reference: str | None
    version: str
    review_status: str
    licensing_attribution: str | None


class DefinitionRead(StrictSchema):
    language: str
    source_language: str
    translation_method: str | None
    simple: str
    standard: str
    technical: str
    review_status: str
    reviewed_by: str | None
    reviewed_at: datetime | None
    record_version: int


class MorphologyComponentRead(StrictSchema):
    element_id: str
    surface: str
    meaning: str
    start: int
    end: int
    position: int


class TermRead(StrictSchema):
    id: str
    canonical_term: str
    normalized_term: str
    pronunciation_text: str | None
    phonetic_representation: str | None
    category_id: str
    subcategory: str | None
    language: str
    review_status: str
    record_version: int
    definitions: list[DefinitionRead]
    synonyms: list[str]
    alternative_spellings: list[str]
    lay_terms: list[str]
    abbreviations: list[str]
    related_term_ids: list[str]
    morphology: list[MorphologyComponentRead]
    examples: list[str]
    source: SourceRead


class SearchResultRead(StrictSchema):
    term: TermRead
    match_type: str
    matched_text: str
    relevance: float
    origin: Literal["remote"] = "remote"
    is_suggestion: bool


class SearchResponse(StrictSchema):
    original_query: str
    normalized_query: str
    resolution_type: str
    ambiguous: bool
    suggested_query: str | None
    page: int
    page_size: int
    total: int
    results: list[SearchResultRead]


class AbbreviationRead(StrictSchema):
    id: str
    term_id: str
    abbreviation: str
    expansion: str
    context: str
    category: str
    ambiguous: bool
    alternative_meanings: list[str]
    safety_warning: str | None


class MorphologyRead(StrictSchema):
    id: str
    element_type: str
    value: str
    meaning: str
    explanation: str
    examples: list[str]
    origin: str | None
    category: str
    language: str
    pronunciation: str | None
    source: SourceRead


class CategoryRead(StrictSchema):
    id: str
    name: str
    description: str
    parent_id: str | None


class LessonSectionRead(StrictSchema):
    id: str
    title: str
    content: str
    section_type: str
    position: int
    linked_term_ids: list[str]


class LessonRead(StrictSchema):
    id: str
    title: str
    description: str
    category_id: str
    difficulty: str
    estimated_minutes: int
    objectives: list[str]
    sections: list[LessonSectionRead]
    review_question_ids: list[str]
    source: SourceRead


class FlashcardRead(StrictSchema):
    id: str
    card_type: str
    front: str
    back: str
    category_id: str
    difficulty: str
    linked_content_id: str | None
    source: SourceRead


class QuizOptionRead(StrictSchema):
    id: str
    text: str


class QuizQuestionRead(StrictSchema):
    id: str
    question_type: str
    prompt: str
    options: list[QuizOptionRead]
    # Explanations are withheld until an answer-evaluation endpoint is added.
    explanation: str | None
    category_id: str
    difficulty: str
    linked_term_id: str | None
    source: SourceRead


class ContentVersionRead(StrictSchema):
    dataset_name: str
    dataset_version: str
    production_approved: bool
    installed_at: datetime
    updated_at: datetime


class SavedItemCreate(StrictSchema):
    id: UUID | None = None
    content_id: str = Field(min_length=1, max_length=100)
    content_type: ContentType


class SavedItemRead(StrictSchema):
    id: UUID
    content_id: str
    content_type: ContentType
    saved_at: datetime


class LearningProgressUpdate(StrictSchema):
    current_streak: int = Field(ge=0, le=100_000)
    longest_streak: int = Field(ge=0, le=100_000)
    last_learning_date: datetime | None = None

    @field_validator("longest_streak")
    @classmethod
    def longest_is_non_negative(cls, value: int) -> int:
        return value


class LearningProgressRead(LearningProgressUpdate):
    updated_at: datetime


class LessonProgressUpdate(StrictSchema):
    lesson_id: str = Field(min_length=1, max_length=100)
    last_section_index: int = Field(ge=0, le=10_000)
    completion_percentage: float = Field(ge=0, le=1)
    started_at: datetime
    updated_at: datetime
    completed_at: datetime | None = None
    review_required: bool = False


class QuizAttemptCreate(StrictSchema):
    id: UUID | None = None
    correct_answers: int = Field(ge=0, le=500)
    total_questions: int = Field(ge=1, le=500)
    category_id: str | None = Field(default=None, max_length=80)
    difficulty: Difficulty | None = None
    answers: list[dict[str, object]] = Field(default_factory=list, max_length=500)
    completed_at: datetime


class QuizAttemptRead(StrictSchema):
    id: UUID
    correct_answers: int
    total_questions: int
    completed_at: datetime


class FlashcardReviewCreate(StrictSchema):
    flashcard_id: str = Field(min_length=1, max_length=100)
    repetitions: int = Field(ge=0, le=10_000)
    ease_factor: float = Field(ge=1.3, le=3.0)
    interval_days: int = Field(ge=0, le=3650)
    performance: Literal["again", "hard", "good", "easy"]
    reviewed_at: datetime
    next_review_at: datetime


class FlashcardReviewRead(FlashcardReviewCreate):
    id: UUID


class ContentReportCreate(StrictSchema):
    id: UUID | None = None
    record_id: str = Field(min_length=1, max_length=100)
    reason: Literal[
        "incorrectDefinition",
        "confusingExplanation",
        "pronunciationIssue",
        "translationIssue",
        "incorrectRelatedTerm",
        "other",
    ]
    note: str | None = Field(default=None, max_length=1000)
    locale: str = Field(min_length=2, max_length=12)
    app_version: str = Field(min_length=1, max_length=40)


class ContentReportRead(StrictSchema):
    id: UUID
    record_id: str
    reason: str
    created_at: datetime
