import json
from pathlib import Path

from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import LearningLesson, QuizOption, QuizQuestion
from app.services.content_import import ContentImporter

DATASET = (
    Path(__file__).resolve().parents[3]
    / "apps/mobile/assets/terminology/learning_expansion_v1.json"
)


def test_additive_learning_catalog_preserves_quizzes_and_admin_edits(client: TestClient) -> None:
    with Session(client.app.state.engine) as db:
        quizzes = [(row.id, row.prompt) for row in db.scalars(select(QuizQuestion))]
        options = [(row.id, row.option_text) for row in db.scalars(select(QuizOption))]
        report = ContentImporter(db).import_path(DATASET, additive=True)
        assert report.lessons == 28
        assert report.flashcards == 56
        lesson = db.get(LearningLesson, "lesson-medicine-labels")
        assert lesson is not None
        lesson.title = "Administrator-edited lesson"
        db.commit()
        assert not ContentImporter(db).import_path(DATASET, additive=True).changed
        updated = json.loads(DATASET.read_text())
        updated["dataset_version"] = "future-additions"
        assert ContentImporter(db).import_document(updated, additive=True).changed
        assert db.get(LearningLesson, lesson.id).title == "Administrator-edited lesson"
        assert [(row.id, row.prompt) for row in db.scalars(select(QuizQuestion))] == quizzes
        assert [(row.id, row.option_text) for row in db.scalars(select(QuizOption))] == options
    lessons = client.get("/api/v1/learning/lessons").json()
    assert len(lessons) == 30
    assert len(client.get("/api/v1/learning/flashcards?limit=100").json()) == 60
    detail = client.get("/api/v1/learning/lessons/lesson-medicine-labels").json()
    assert len(detail["sections"]) == 3
    assert detail["source"]["canonical_reference"].startswith("https://www.fda.gov/")
