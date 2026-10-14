from uuid import UUID

from fastapi import APIRouter, HTTPException, Response, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from app.api.dependencies import CurrentIdentityDependency, DatabaseDependency
from app.core.time import utc_now
from app.models import (
    FlashcardReview,
    LearningProgress,
    LessonProgress,
    QuizAttempt,
    SavedItem,
)
from app.schemas.module2 import (
    FlashcardReviewCreate,
    FlashcardReviewRead,
    LearningProgressRead,
    LearningProgressUpdate,
    LessonProgressUpdate,
    QuizAttemptCreate,
    QuizAttemptRead,
    SavedItemCreate,
    SavedItemRead,
)

router = APIRouter(prefix="/me", tags=["module-2-user-data"])


@router.get("/saved", response_model=list[SavedItemRead])
def saved_items(identity: CurrentIdentityDependency, db: DatabaseDependency) -> list[SavedItemRead]:
    values = db.scalars(
        select(SavedItem)
        .where(SavedItem.user_id == identity.user.id)
        .order_by(SavedItem.saved_at.desc())
    ).all()
    return [SavedItemRead.model_validate(value) for value in values]


@router.post("/saved", response_model=SavedItemRead, status_code=status.HTTP_201_CREATED)
def save_item(
    payload: SavedItemCreate,
    identity: CurrentIdentityDependency,
    db: DatabaseDependency,
) -> SavedItemRead:
    existing = db.scalar(
        select(SavedItem).where(
            SavedItem.user_id == identity.user.id,
            SavedItem.content_id == payload.content_id,
            SavedItem.content_type == payload.content_type,
        )
    )
    if existing is not None:
        return SavedItemRead.model_validate(existing)
    data = payload.model_dump(exclude={"id"})
    value = (
        SavedItem(id=payload.id, user_id=identity.user.id, **data)
        if payload.id
        else SavedItem(user_id=identity.user.id, **data)
    )
    db.add(value)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        existing = db.scalar(
            select(SavedItem).where(
                SavedItem.user_id == identity.user.id,
                SavedItem.content_id == payload.content_id,
                SavedItem.content_type == payload.content_type,
            )
        )
        if existing is None:
            raise
        return SavedItemRead.model_validate(existing)
    db.refresh(value)
    return SavedItemRead.model_validate(value)


@router.delete("/saved/{saved_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_saved_item(
    saved_id: UUID,
    identity: CurrentIdentityDependency,
    db: DatabaseDependency,
) -> Response:
    value = db.get(SavedItem, saved_id)
    if value is None or value.user_id != identity.user.id:
        raise HTTPException(status_code=404, detail="Saved item not found")
    db.delete(value)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/learning-progress", response_model=LearningProgressRead)
def read_progress(
    identity: CurrentIdentityDependency,
    db: DatabaseDependency,
) -> LearningProgressRead:
    value = db.get(LearningProgress, identity.user.id)
    if value is None:
        return LearningProgressRead(
            current_streak=0,
            longest_streak=0,
            last_learning_date=None,
            updated_at=utc_now(),
        )
    return LearningProgressRead.model_validate(value)


@router.put("/lesson-progress/{lesson_id}", response_model=LessonProgressUpdate)
def update_lesson_progress(
    lesson_id: str,
    payload: LessonProgressUpdate,
    identity: CurrentIdentityDependency,
    db: DatabaseDependency,
) -> LessonProgressUpdate:
    if payload.lesson_id != lesson_id:
        raise HTTPException(status_code=422, detail="Lesson ID does not match path")
    value = db.get(LessonProgress, (identity.user.id, lesson_id))
    if value is None:
        value = LessonProgress(user_id=identity.user.id, **payload.model_dump())
        db.add(value)
    else:
        for key, item in payload.model_dump().items():
            setattr(value, key, item)
    db.commit()
    db.refresh(value)
    return LessonProgressUpdate.model_validate(value)


@router.put("/learning-progress", response_model=LearningProgressRead)
def update_progress(
    payload: LearningProgressUpdate,
    identity: CurrentIdentityDependency,
    db: DatabaseDependency,
) -> LearningProgressRead:
    if payload.longest_streak < payload.current_streak:
        raise HTTPException(status_code=422, detail="Longest streak cannot be shorter")
    value = db.get(LearningProgress, identity.user.id)
    if value is None:
        value = LearningProgress(user_id=identity.user.id)
        db.add(value)
    value.current_streak = payload.current_streak
    value.longest_streak = payload.longest_streak
    value.last_learning_date = payload.last_learning_date
    value.updated_at = utc_now()
    db.commit()
    db.refresh(value)
    return LearningProgressRead.model_validate(value)


@router.post("/quiz-attempts", response_model=QuizAttemptRead, status_code=201)
def record_quiz_attempt(
    payload: QuizAttemptCreate,
    identity: CurrentIdentityDependency,
    db: DatabaseDependency,
) -> QuizAttemptRead:
    if payload.correct_answers > payload.total_questions:
        raise HTTPException(status_code=422, detail="Correct answers exceed total")
    if payload.id:
        existing = db.get(QuizAttempt, payload.id)
        if existing is not None:
            if existing.user_id != identity.user.id:
                raise HTTPException(status_code=404, detail="Quiz attempt not found")
            return QuizAttemptRead.model_validate(existing)
    data = payload.model_dump(exclude={"id"})
    value = (
        QuizAttempt(user_id=identity.user.id, id=payload.id, **data)
        if payload.id
        else QuizAttempt(user_id=identity.user.id, **data)
    )
    db.add(value)
    db.commit()
    db.refresh(value)
    return QuizAttemptRead.model_validate(value)


@router.post("/flashcard-reviews", response_model=FlashcardReviewRead, status_code=201)
def record_flashcard_review(
    payload: FlashcardReviewCreate,
    identity: CurrentIdentityDependency,
    db: DatabaseDependency,
) -> FlashcardReviewRead:
    value = db.scalar(
        select(FlashcardReview).where(
            FlashcardReview.user_id == identity.user.id,
            FlashcardReview.flashcard_id == payload.flashcard_id,
        )
    )
    if value is None:
        value = FlashcardReview(user_id=identity.user.id, **payload.model_dump())
        db.add(value)
    else:
        for key, item in payload.model_dump().items():
            setattr(value, key, item)
    db.commit()
    db.refresh(value)
    return FlashcardReviewRead.model_validate(value)
