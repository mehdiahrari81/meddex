from pathlib import Path

from fastapi.testclient import TestClient
from sqlalchemy import create_engine, func, select
from sqlalchemy.orm import Session

from app.db.base import Base
from app.models import MedicalTerm
from app.services.content_import import ContentImporter, DatasetValidationError
from tests.conftest import auth_headers


def test_exact_case_normalized_synonym_lay_partial_fuzzy_and_no_result(client: TestClient) -> None:
    cases = [
        ("hypertension", "exact", "Hypertension"),
        ("HYPERTENSION", "exact", "Hypertension"),
        ("  hypertension!! ", "exact", "Hypertension"),
        ("rapid heart rate", "synonym", "Tachycardia"),
        ("high blood pressure", "layEquivalent", "Hypertension"),
        ("tachy", "partial", "Tachycardia"),
        ("cardiomyopaty", "fuzzy", "Cardiomyopathy"),
    ]
    for query, resolution, term in cases:
        response = client.get("/api/v1/terms/search", params={"q": query})
        assert response.status_code == 200, response.text
        body = response.json()
        assert body["resolution_type"] == resolution
        assert body["results"][0]["term"]["canonical_term"] == term
    missing = client.get("/api/v1/terms/search", params={"q": "zzzzunknown"})
    assert missing.status_code == 200
    assert missing.json()["resolution_type"] == "noMatch"


def test_search_ranking_pagination_filtering_and_invalid_query(client: TestClient) -> None:
    ranked = client.get("/api/v1/terms/search", params={"q": "heart rate"}).json()
    assert ranked["results"][0]["term"]["canonical_term"] == "Heart rate"
    assert ranked["results"][0]["match_type"] == "exact"
    page = client.get(
        "/api/v1/terms/search",
        params={"q": "hyp", "page": 1, "page_size": 1, "category": "endocrine"},
    )
    assert page.status_code == 200
    assert page.json()["page_size"] == 1
    assert len(page.json()["results"]) <= 1
    assert all(result["term"]["category_id"] == "endocrine" for result in page.json()["results"])
    assert client.get("/api/v1/terms/search", params={"q": ""}).status_code == 422
    assert (
        client.get("/api/v1/terms/search", params={"q": "x", "page_size": 101}).status_code == 422
    )


def test_abbreviation_ambiguity_and_complete_required_abbreviation_set(client: TestClient) -> None:
    response = client.get("/api/v1/terms/search", params={"q": "MS"})
    assert response.status_code == 200
    assert response.json()["ambiguous"] is True
    assert response.json()["resolution_type"] == "ambiguous"
    assert len(response.json()["results"]) == 2
    abbreviations = client.get("/api/v1/abbreviations").json()
    required = {"BP", "HR", "NPO", "PRN", "PO", "IV", "IM", "BID", "TID", "QID"}
    assert required <= {item["abbreviation"] for item in abbreviations}


def test_term_source_related_morphology_categories_and_content_version(client: TestClient) -> None:
    term = client.get("/api/v1/terms/term-tachycardia")
    assert term.status_code == 200
    body = term.json()
    assert body["source"]["identifier"] == "mediexplain-dev-seed-2026.08.2"
    assert body["source"]["licensing_attribution"]
    assert body["definitions"][0]["source_language"] == "en"
    assert body["definitions"][0]["translation_method"] == "original"
    assert len(body["morphology"]) == 3
    assert client.get("/api/v1/terms/term-tachycardia/related").status_code == 200
    assert client.get("/api/v1/morphology/prefixes").json()
    assert client.get("/api/v1/morphology/roots").json()
    assert client.get("/api/v1/morphology/suffixes").json()
    assert client.get("/api/v1/categories").json()
    version = client.get("/api/v1/content/version")
    assert version.status_code == 200
    assert version.json()["dataset_version"] == "2026.08.3"
    assert version.json()["production_approved"] is False


def test_draft_and_deprecated_content_are_not_published(client: TestClient) -> None:
    engine = client.app.state.engine
    with Session(engine) as db:
        draft = db.get(MedicalTerm, "term-hypertension")
        assert draft is not None
        draft.review_status = "draft"
        db.commit()
    assert client.get("/api/v1/terms/term-hypertension").status_code == 404
    results = client.get("/api/v1/terms/search", params={"q": "hypertension"}).json()["results"]
    assert all(item["term"]["id"] != "term-hypertension" for item in results)


def test_development_seed_is_not_published_in_production(client: TestClient) -> None:
    client.app.state.settings.environment = "production"
    assert client.get("/api/v1/terms/term-hypertension").status_code == 404
    assert client.get("/api/v1/terms/search", params={"q": "hypertension"}).json()["results"] == []
    assert client.get("/api/v1/learning/lessons").json() == []
    assert client.get("/api/v1/learning/flashcards").json() == []
    assert client.get("/api/v1/learning/quizzes").json() == []


def test_learning_content_does_not_expose_correct_answers(client: TestClient) -> None:
    assert client.get("/api/v1/learning/lessons").json()
    assert client.get("/api/v1/learning/lessons/lesson-intro-morphology").status_code == 200
    assert client.get("/api/v1/learning/flashcards").json()
    quizzes = client.get("/api/v1/learning/quizzes").json()
    assert quizzes
    assert all("is_correct" not in option for question in quizzes for option in question["options"])
    assert all(question["explanation"] is None for question in quizzes)


def test_saved_item_duplicate_delete_and_unauthorized(
    client: TestClient, registered: dict[str, str]
) -> None:
    assert client.get("/api/v1/me/saved").status_code == 401
    headers = auth_headers(registered["access_token"])
    payload = {"content_id": "term-hypertension", "content_type": "term"}
    first = client.post("/api/v1/me/saved", headers=headers, json=payload)
    second = client.post("/api/v1/me/saved", headers=headers, json=payload)
    assert first.status_code == 201
    assert second.status_code == 201
    assert first.json()["id"] == second.json()["id"]
    assert len(client.get("/api/v1/me/saved", headers=headers).json()) == 1
    deleted = client.delete(f"/api/v1/me/saved/{first.json()['id']}", headers=headers)
    assert deleted.status_code == 204

    stable_id = "1024983e-f436-45fe-9168-c812578d1f21"
    stable = client.post(
        "/api/v1/me/saved",
        headers=headers,
        json={**payload, "id": stable_id},
    )
    assert stable.status_code == 201
    assert stable.json()["id"] == stable_id


def test_learning_progress_quiz_review_authorization(
    client: TestClient, registered: dict[str, str]
) -> None:
    progress = {"current_streak": 2, "longest_streak": 3, "last_learning_date": None}
    assert client.put("/api/v1/me/learning-progress", json=progress).status_code == 401
    headers = auth_headers(registered["access_token"])
    updated = client.put("/api/v1/me/learning-progress", headers=headers, json=progress)
    assert updated.status_code == 200
    lesson = client.put(
        "/api/v1/me/lesson-progress/lesson-intro-morphology",
        headers=headers,
        json={
            "lesson_id": "lesson-intro-morphology",
            "last_section_index": 1,
            "completion_percentage": 0.66,
            "started_at": "2026-08-12T00:00:00Z",
            "updated_at": "2026-08-12T00:03:00Z",
            "review_required": False,
        },
    )
    assert lesson.status_code == 200, lesson.text
    attempt = client.post(
        "/api/v1/me/quiz-attempts",
        headers=headers,
        json={
            "correct_answers": 2,
            "total_questions": 3,
            "answers": [],
            "completed_at": "2026-08-12T00:00:00Z",
        },
    )
    assert attempt.status_code == 201, attempt.text
    review = client.post(
        "/api/v1/me/flashcard-reviews",
        headers=headers,
        json={
            "flashcard_id": "card-tachy-meaning",
            "repetitions": 1,
            "ease_factor": 2.5,
            "interval_days": 1,
            "performance": "good",
            "reviewed_at": "2026-08-12T00:00:00Z",
            "next_review_at": "2026-08-13T00:00:00Z",
        },
    )
    assert review.status_code == 201, review.text


def test_content_report_validation_and_submission(client: TestClient) -> None:
    response = client.post(
        "/api/v1/reports/content",
        json={
            "record_id": "term-hypertension",
            "reason": "confusingExplanation",
            "note": "Please review wording.",
            "locale": "en",
            "app_version": "1.0.0+1",
        },
    )
    assert response.status_code == 201
    report_id = "2def2e87-90f8-4e61-a92b-e9511015d2b2"
    idempotent_payload = {
        "id": report_id,
        "record_id": "term-hypertension",
        "reason": "other",
        "locale": "en",
        "app_version": "1.0.0+1",
    }
    first = client.post("/api/v1/reports/content", json=idempotent_payload)
    second = client.post("/api/v1/reports/content", json=idempotent_payload)
    assert first.status_code == second.status_code == 201
    assert first.json()["id"] == second.json()["id"] == report_id
    invalid = client.post(
        "/api/v1/reports/content",
        json={"record_id": "x", "reason": "hack", "locale": "en", "app_version": "1"},
    )
    assert invalid.status_code == 422


def test_importer_dry_run_duplicate_detection_and_idempotency(tmp_path: Path) -> None:
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)
    dataset = (
        Path(__file__).resolve().parents[3]
        / "apps/mobile/assets/terminology/starter_dataset_v1.json"
    )
    with Session(engine) as db:
        importer = ContentImporter(db)
        dry = importer.import_path(dataset, dry_run=True)
        assert dry.terms == 34
        assert db.scalar(select(func.count()).select_from(MedicalTerm)) == 0
        first = importer.import_path(dataset)
        second = importer.import_path(dataset)
        assert first.changed is True
        assert second.changed is False
        assert db.scalar(select(func.count()).select_from(MedicalTerm)) == 34
        broken = tmp_path / "broken.json"
        contents = dataset.read_text().replace(
            '"id":"term-hypotension"', '"id":"term-hypertension"', 1
        )
        broken.write_text(contents)
        try:
            importer.import_path(broken, dry_run=True)
        except DatasetValidationError:
            pass
        else:
            raise AssertionError("Duplicate term ID was accepted")
    engine.dispose()
