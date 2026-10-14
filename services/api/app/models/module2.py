from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import (
    JSON,
    Boolean,
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.time import utc_now
from app.db.base import Base


class ContentSource(Base):
    __tablename__ = "content_sources"

    id: Mapped[str] = mapped_column(String(100), primary_key=True)
    provider: Mapped[str] = mapped_column(String(200))
    title: Mapped[str] = mapped_column(String(300))
    identifier: Mapped[str] = mapped_column(String(200), unique=True)
    canonical_reference: Mapped[str | None] = mapped_column(String(1000))
    locale: Mapped[str] = mapped_column(String(12), default="en")
    version: Mapped[str] = mapped_column(String(60))
    review_status: Mapped[str] = mapped_column(String(20), index=True)
    content_type: Mapped[str] = mapped_column(String(80))
    licensing_attribution: Mapped[str | None] = mapped_column(Text)
    retrieved_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    source_updated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class Category(Base):
    __tablename__ = "categories"

    id: Mapped[str] = mapped_column(String(80), primary_key=True)
    name: Mapped[str] = mapped_column(String(160))
    description: Mapped[str] = mapped_column(Text)
    parent_id: Mapped[str | None] = mapped_column(ForeignKey("categories.id"))
    position: Mapped[int] = mapped_column(Integer, default=0)


class MedicalTerm(Base):
    __tablename__ = "medical_terms"
    __table_args__ = (
        Index("ix_medical_terms_normalized_language", "normalized_term", "language"),
        Index("ix_medical_terms_category_status", "category_id", "review_status"),
    )

    id: Mapped[str] = mapped_column(String(100), primary_key=True)
    canonical_term: Mapped[str] = mapped_column(String(300))
    normalized_term: Mapped[str] = mapped_column(String(300), index=True)
    pronunciation_text: Mapped[str | None] = mapped_column(String(300))
    phonetic_representation: Mapped[str | None] = mapped_column(String(300))
    category_id: Mapped[str] = mapped_column(ForeignKey("categories.id"), index=True)
    subcategory: Mapped[str | None] = mapped_column(String(120))
    language: Mapped[str] = mapped_column(String(12), default="en", index=True)
    review_status: Mapped[str] = mapped_column(String(20), index=True)
    record_version: Mapped[int] = mapped_column(Integer)
    deprecated: Mapped[bool] = mapped_column(Boolean, default=False)
    replacement_term_id: Mapped[str | None] = mapped_column(String(100))
    source_id: Mapped[str] = mapped_column(ForeignKey("content_sources.id"))
    examples: Mapped[list[str]] = mapped_column(JSON, default=list)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)


class TermDefinition(Base):
    __tablename__ = "term_definitions"
    __table_args__ = (UniqueConstraint("term_id", "language", name="uq_definition_language"),)

    id: Mapped[str] = mapped_column(String(130), primary_key=True)
    term_id: Mapped[str] = mapped_column(
        ForeignKey("medical_terms.id", ondelete="CASCADE"), index=True
    )
    language: Mapped[str] = mapped_column(String(12), index=True)
    source_language: Mapped[str] = mapped_column(String(12), default="en")
    translation_method: Mapped[str | None] = mapped_column(String(80))
    simple_definition: Mapped[str] = mapped_column(Text)
    standard_definition: Mapped[str] = mapped_column(Text)
    technical_definition: Mapped[str] = mapped_column(Text)
    review_status: Mapped[str] = mapped_column(String(20), index=True)
    reviewed_by: Mapped[str | None] = mapped_column(String(200))
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    record_version: Mapped[int] = mapped_column(Integer)


class TermAlias(Base):
    __tablename__ = "term_aliases"
    __table_args__ = (
        UniqueConstraint(
            "term_id", "normalized_alias", "alias_type", "language", name="uq_term_alias"
        ),
        Index("ix_term_alias_search", "normalized_alias", "alias_type"),
    )

    id: Mapped[str] = mapped_column(String(150), primary_key=True)
    term_id: Mapped[str] = mapped_column(
        ForeignKey("medical_terms.id", ondelete="CASCADE"), index=True
    )
    alias: Mapped[str] = mapped_column(String(300))
    normalized_alias: Mapped[str] = mapped_column(String(300), index=True)
    alias_type: Mapped[str] = mapped_column(String(30))
    language: Mapped[str] = mapped_column(String(12), default="en")


class MedicalAbbreviation(Base):
    __tablename__ = "abbreviations"
    __table_args__ = (Index("ix_abbreviation_lookup", "normalized_abbreviation"),)

    id: Mapped[str] = mapped_column(String(100), primary_key=True)
    term_id: Mapped[str] = mapped_column(
        ForeignKey("medical_terms.id", ondelete="CASCADE"), index=True
    )
    abbreviation: Mapped[str] = mapped_column(String(40))
    normalized_abbreviation: Mapped[str] = mapped_column(String(40), index=True)
    expansion: Mapped[str] = mapped_column(String(300))
    context: Mapped[str] = mapped_column(Text)
    category: Mapped[str] = mapped_column(String(100), index=True)
    ambiguous: Mapped[bool] = mapped_column(Boolean)
    alternative_meanings: Mapped[list[str]] = mapped_column(JSON, default=list)
    safety_warning: Mapped[str | None] = mapped_column(Text)


class MorphologyElement(Base):
    __tablename__ = "morphology_elements"
    __table_args__ = (
        UniqueConstraint("element_type", "normalized_value", "language", name="uq_morphology"),
        Index("ix_morphology_type_category", "element_type", "category"),
    )

    id: Mapped[str] = mapped_column(String(100), primary_key=True)
    element_type: Mapped[str] = mapped_column(String(20), index=True)
    value: Mapped[str] = mapped_column(String(100))
    normalized_value: Mapped[str] = mapped_column(String(100), index=True)
    meaning: Mapped[str] = mapped_column(String(300))
    explanation: Mapped[str] = mapped_column(Text)
    examples: Mapped[list[str]] = mapped_column(JSON, default=list)
    origin: Mapped[str | None] = mapped_column(String(120))
    category: Mapped[str] = mapped_column(String(100), index=True)
    language: Mapped[str] = mapped_column(String(12), default="en")
    pronunciation: Mapped[str | None] = mapped_column(String(300))
    related_element_ids: Mapped[list[str]] = mapped_column(JSON, default=list)
    review_status: Mapped[str] = mapped_column(String(20), index=True)
    source_id: Mapped[str] = mapped_column(ForeignKey("content_sources.id"))


class TermMorphology(Base):
    __tablename__ = "term_morphology"

    id: Mapped[str] = mapped_column(String(150), primary_key=True)
    term_id: Mapped[str] = mapped_column(
        ForeignKey("medical_terms.id", ondelete="CASCADE"), index=True
    )
    element_id: Mapped[str] = mapped_column(ForeignKey("morphology_elements.id"))
    surface_text: Mapped[str] = mapped_column(String(100))
    meaning: Mapped[str] = mapped_column(String(300))
    start_offset: Mapped[int] = mapped_column(Integer)
    end_offset: Mapped[int] = mapped_column(Integer)
    position: Mapped[int] = mapped_column(Integer)


class TermRelation(Base):
    __tablename__ = "term_relations"

    source_term_id: Mapped[str] = mapped_column(
        ForeignKey("medical_terms.id", ondelete="CASCADE"), primary_key=True
    )
    target_term_id: Mapped[str] = mapped_column(
        ForeignKey("medical_terms.id", ondelete="CASCADE"), primary_key=True
    )
    relation_type: Mapped[str] = mapped_column(String(40), primary_key=True, default="related")


class LearningLesson(Base):
    __tablename__ = "learning_lessons"

    id: Mapped[str] = mapped_column(String(100), primary_key=True)
    title: Mapped[str] = mapped_column(String(300))
    description: Mapped[str] = mapped_column(Text)
    category_id: Mapped[str] = mapped_column(ForeignKey("categories.id"), index=True)
    difficulty: Mapped[str] = mapped_column(String(30), index=True)
    estimated_minutes: Mapped[int] = mapped_column(Integer)
    objectives: Mapped[list[str]] = mapped_column(JSON, default=list)
    review_question_ids: Mapped[list[str]] = mapped_column(JSON, default=list)
    review_status: Mapped[str] = mapped_column(String(20), index=True)
    record_version: Mapped[int] = mapped_column(Integer)
    source_id: Mapped[str] = mapped_column(ForeignKey("content_sources.id"))


class LessonSection(Base):
    __tablename__ = "lesson_sections"

    id: Mapped[str] = mapped_column(String(120), primary_key=True)
    lesson_id: Mapped[str] = mapped_column(
        ForeignKey("learning_lessons.id", ondelete="CASCADE"), index=True
    )
    title: Mapped[str] = mapped_column(String(300))
    content: Mapped[str] = mapped_column(Text)
    section_type: Mapped[str] = mapped_column(String(30))
    position: Mapped[int] = mapped_column(Integer)
    linked_term_ids: Mapped[list[str]] = mapped_column(JSON, default=list)


class Flashcard(Base):
    __tablename__ = "flashcards"

    id: Mapped[str] = mapped_column(String(100), primary_key=True)
    card_type: Mapped[str] = mapped_column(String(40))
    front: Mapped[str] = mapped_column(Text)
    back: Mapped[str] = mapped_column(Text)
    category_id: Mapped[str] = mapped_column(ForeignKey("categories.id"), index=True)
    difficulty: Mapped[str] = mapped_column(String(30), index=True)
    linked_content_id: Mapped[str | None] = mapped_column(String(100))
    source_id: Mapped[str] = mapped_column(ForeignKey("content_sources.id"))


class QuizQuestion(Base):
    __tablename__ = "quiz_questions"

    id: Mapped[str] = mapped_column(String(100), primary_key=True)
    question_type: Mapped[str] = mapped_column(String(40))
    prompt: Mapped[str] = mapped_column(Text)
    explanation: Mapped[str] = mapped_column(Text)
    category_id: Mapped[str] = mapped_column(ForeignKey("categories.id"), index=True)
    difficulty: Mapped[str] = mapped_column(String(30), index=True)
    linked_term_id: Mapped[str | None] = mapped_column(ForeignKey("medical_terms.id"))
    source_id: Mapped[str] = mapped_column(ForeignKey("content_sources.id"))


class QuizOption(Base):
    __tablename__ = "quiz_options"

    id: Mapped[str] = mapped_column(String(100), primary_key=True)
    question_id: Mapped[str] = mapped_column(
        ForeignKey("quiz_questions.id", ondelete="CASCADE"), index=True
    )
    option_text: Mapped[str] = mapped_column(Text)
    is_correct: Mapped[bool] = mapped_column(Boolean)
    position: Mapped[int] = mapped_column(Integer)


class ContentVersion(Base):
    __tablename__ = "content_versions"

    dataset_name: Mapped[str] = mapped_column(String(150), primary_key=True)
    dataset_version: Mapped[str] = mapped_column(String(80))
    production_approved: Mapped[bool] = mapped_column(Boolean, default=False)
    installed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)


class SavedItem(Base):
    __tablename__ = "saved_items"
    __table_args__ = (
        UniqueConstraint("user_id", "content_id", "content_type", name="uq_user_saved_item"),
    )

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    content_id: Mapped[str] = mapped_column(String(100))
    content_type: Mapped[str] = mapped_column(String(30))
    saved_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)


class LearningProgress(Base):
    __tablename__ = "learning_progress"

    user_id: Mapped[UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    current_streak: Mapped[int] = mapped_column(Integer, default=0)
    longest_streak: Mapped[int] = mapped_column(Integer, default=0)
    last_learning_date: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)


class LessonProgress(Base):
    __tablename__ = "lesson_progress"

    user_id: Mapped[UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    lesson_id: Mapped[str] = mapped_column(ForeignKey("learning_lessons.id"), primary_key=True)
    last_section_index: Mapped[int] = mapped_column(Integer)
    completion_percentage: Mapped[float] = mapped_column(Float)
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    review_required: Mapped[bool] = mapped_column(Boolean, default=False)


class QuizAttempt(Base):
    __tablename__ = "quiz_attempts"

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    correct_answers: Mapped[int] = mapped_column(Integer)
    total_questions: Mapped[int] = mapped_column(Integer)
    category_id: Mapped[str | None] = mapped_column(String(80))
    difficulty: Mapped[str | None] = mapped_column(String(30))
    answers: Mapped[list[dict[str, object]]] = mapped_column(JSON, default=list)
    completed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class FlashcardReview(Base):
    __tablename__ = "flashcard_reviews"
    __table_args__ = (UniqueConstraint("user_id", "flashcard_id", name="uq_flashcard_schedule"),)

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    flashcard_id: Mapped[str] = mapped_column(ForeignKey("flashcards.id"), index=True)
    repetitions: Mapped[int] = mapped_column(Integer)
    ease_factor: Mapped[float] = mapped_column(Float)
    interval_days: Mapped[int] = mapped_column(Integer)
    performance: Mapped[str] = mapped_column(String(20))
    reviewed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    next_review_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)


class ContentReport(Base):
    __tablename__ = "content_reports"

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    user_id: Mapped[UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), index=True
    )
    record_id: Mapped[str] = mapped_column(String(100), index=True)
    reason: Mapped[str] = mapped_column(String(40))
    note: Mapped[str | None] = mapped_column(String(1000))
    locale: Mapped[str] = mapped_column(String(12))
    app_version: Mapped[str] = mapped_column(String(40))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
