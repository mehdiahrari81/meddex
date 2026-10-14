from typing import Annotated

from fastapi import APIRouter, HTTPException, Query
from sqlalchemy import select

from app.api.dependencies import DatabaseDependency, SettingsDependency
from app.api.v1.routers.terminology import _published_statuses, _source
from app.models import (
    ContentSource,
    Flashcard,
    LearningLesson,
    LessonSection,
    QuizOption,
    QuizQuestion,
)
from app.schemas.module2 import (
    FlashcardRead,
    LessonRead,
    LessonSectionRead,
    QuizOptionRead,
    QuizQuestionRead,
)

router = APIRouter(prefix="/learning", tags=["learning-content"])
Limit = Annotated[int, Query(ge=1, le=100)]


def _lesson(db: DatabaseDependency, value: LearningLesson) -> LessonRead:
    sections = db.scalars(
        select(LessonSection)
        .where(LessonSection.lesson_id == value.id)
        .order_by(LessonSection.position)
    ).all()
    return LessonRead(
        id=value.id,
        title=value.title,
        description=value.description,
        category_id=value.category_id,
        difficulty=value.difficulty,
        estimated_minutes=value.estimated_minutes,
        objectives=value.objectives,
        sections=[LessonSectionRead.model_validate(section) for section in sections],
        review_question_ids=value.review_question_ids,
        source=_source(db, value.source_id),
    )


@router.get("/lessons", response_model=list[LessonRead])
def lessons(
    db: DatabaseDependency,
    settings: SettingsDependency,
    difficulty: str | None = Query(default=None, pattern="^(beginner|intermediate|advanced)$"),
    category: str | None = Query(default=None, max_length=80),
    limit: Limit = 50,
) -> list[LessonRead]:
    statement = (
        select(LearningLesson)
        .where(LearningLesson.review_status.in_(_published_statuses(settings)))
        .order_by(LearningLesson.title)
        .limit(limit)
    )
    if difficulty:
        statement = statement.where(LearningLesson.difficulty == difficulty)
    if category:
        statement = statement.where(LearningLesson.category_id == category)
    return [_lesson(db, item) for item in db.scalars(statement).all()]


@router.get("/lessons/{lesson_id}", response_model=LessonRead)
def lesson_detail(
    lesson_id: str,
    db: DatabaseDependency,
    settings: SettingsDependency,
) -> LessonRead:
    value = db.get(LearningLesson, lesson_id)
    if value is None or value.review_status not in _published_statuses(settings):
        raise HTTPException(status_code=404, detail="Lesson not found")
    return _lesson(db, value)


@router.get("/flashcards", response_model=list[FlashcardRead])
def flashcards(
    db: DatabaseDependency,
    settings: SettingsDependency,
    difficulty: str | None = Query(default=None, pattern="^(beginner|intermediate|advanced)$"),
    category: str | None = Query(default=None, max_length=80),
    limit: Limit = 20,
) -> list[FlashcardRead]:
    statement = (
        select(Flashcard)
        .join(ContentSource, ContentSource.id == Flashcard.source_id)
        .where(ContentSource.review_status.in_(_published_statuses(settings)))
        .order_by(Flashcard.id)
        .limit(limit)
    )
    if difficulty:
        statement = statement.where(Flashcard.difficulty == difficulty)
    if category:
        statement = statement.where(Flashcard.category_id == category)
    return [
        FlashcardRead(
            id=item.id,
            card_type=item.card_type,
            front=item.front,
            back=item.back,
            category_id=item.category_id,
            difficulty=item.difficulty,
            linked_content_id=item.linked_content_id,
            source=_source(db, item.source_id),
        )
        for item in db.scalars(statement).all()
    ]


@router.get("/quizzes", response_model=list[QuizQuestionRead])
def quizzes(
    db: DatabaseDependency,
    settings: SettingsDependency,
    difficulty: str | None = Query(default=None, pattern="^(beginner|intermediate|advanced)$"),
    category: str | None = Query(default=None, max_length=80),
    limit: Limit = 20,
) -> list[QuizQuestionRead]:
    statement = (
        select(QuizQuestion)
        .join(ContentSource, ContentSource.id == QuizQuestion.source_id)
        .where(ContentSource.review_status.in_(_published_statuses(settings)))
        .order_by(QuizQuestion.id)
        .limit(limit)
    )
    if difficulty:
        statement = statement.where(QuizQuestion.difficulty == difficulty)
    if category:
        statement = statement.where(QuizQuestion.category_id == category)
    result = []
    for item in db.scalars(statement).all():
        options = db.scalars(
            select(QuizOption)
            .where(QuizOption.question_id == item.id)
            .order_by(QuizOption.position)
        ).all()
        result.append(
            QuizQuestionRead(
                id=item.id,
                question_type=item.question_type,
                prompt=item.prompt,
                options=[
                    QuizOptionRead(id=option.id, text=option.option_text) for option in options
                ],
                explanation=None,
                category_id=item.category_id,
                difficulty=item.difficulty,
                linked_term_id=item.linked_term_id,
                source=_source(db, item.source_id),
            )
        )
    return result
