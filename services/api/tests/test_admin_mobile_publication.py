"""Real editorial writes must reach public APIs and versioned mobile downloads."""

import copy
from uuid import UUID

import pytest
from sqlalchemy import func, select

from app.models import AuditEvent, Flashcard, GovernedContent, LearningLesson, MedicalTerm
from app.services.reference_publication import ReferencePublicationService
from tests.test_admin import _admin, _headers
from tests.test_reference_releases import _document


@pytest.fixture
def editors(client):
    author = _admin(client, "SUPER_ADMIN", "publication-author@example.com")
    reviewer = _admin(client, "CONTENT_REVIEWER", "publication-reviewer@example.com")
    return author, _headers(author["access_token"]), _headers(reviewer["access_token"])


def save(client, headers, stable_id, kind, content):
    return client.post(
        "/api/v1/admin/content",
        headers=headers,
        json={
            "stable_id": stable_id,
            "content_type": kind,
            "content": content,
            "source_metadata": {"origin": "isolated engineering verification"},
            "change_reason": "Verify real publication data flow in isolated test storage",
        },
    )


def action(client, headers, stable_id, name):
    return client.post(
        f"/api/v1/admin/content/{stable_id}/workflow",
        headers=headers,
        json={
            "action": name,
            "reason": "Reviewed isolated publication fixture",
            "confirmation": stable_id,
        },
    )


def fixture(kind):
    mapping = {
        "lesson": "lessons",
        "flashcard": "flashcards",
        "terminology": "terms",
        "morphology": "morphology",
        "abbreviation": "abbreviations",
        "quiz": "quiz_questions",
    }
    content = copy.deepcopy(_document()[mapping[kind]][0])
    content["id"] = "publication-fixture-" + kind
    if kind == "lesson":
        content["title"] = "Isolated publication lesson"
        for index, section in enumerate(content["sections"]):
            section["id"] = f"publication-section-{index}"
    if kind == "terminology":
        content["term"] = "Isolated publication fixture term"
    if kind == "abbreviation":
        content["abbreviation"] = "TEST-ONLY"
    if kind == "morphology":
        content["value"] = "fixture-only-"
    if kind == "quiz":
        for index, option in enumerate(content["options"]):
            option["id"] = f"publication-option-{index}"
    return mapping[kind], content


@pytest.mark.parametrize(
    "kind", ["lesson", "flashcard", "terminology", "morphology", "abbreviation", "quiz"]
)
def test_draft_hidden_publish_updates_download_and_withdrawal(client, editors, kind):
    _, author, reviewer = editors
    collection, content = fixture(kind)
    stable_id = kind + ".publication-fixture"
    assert save(client, author, stable_id, kind, content).status_code == 201
    assert client.get("/api/v1/content/dataset").status_code == 404
    assert action(client, author, stable_id, "submit_review").status_code == 200
    assert action(client, reviewer, stable_id, "approve").status_code == 200
    # Approved drafts still cannot leak before publication.
    assert client.get("/api/v1/content/dataset").status_code == 404
    assert action(client, reviewer, stable_id, "publish").status_code == 200
    document = client.get("/api/v1/content/dataset").json()
    assert any(row["id"] == content["id"] for row in document[collection])
    assert (
        client.get("/api/v1/content/version").json()["dataset_version"]
        == document["dataset_version"]
    )
    if kind == "lesson":
        assert (
            client.get("/api/v1/learning/lessons/" + content["id"]).json()["title"]
            == content["title"]
        )
    # A new draft preserves the last published result on the phone.
    draft = copy.deepcopy(content)
    if kind == "lesson":
        draft["title"] = "This draft must remain hidden"
    assert save(client, author, stable_id, kind, draft).status_code == 201
    assert client.get("/api/v1/content/dataset").json() == document
    # Publish that revision then exercise withdrawal without deleting user history.
    for name, headers in [("submit_review", author), ("approve", reviewer), ("publish", reviewer)]:
        assert action(client, headers, stable_id, name).status_code == 200
    assert action(client, reviewer, stable_id, "deprecate").status_code == 200
    withdrawn = client.get("/api/v1/content/dataset").json()
    if kind == "abbreviation":
        assert content["id"] in withdrawn["withdrawn_abbreviation_ids"]
        assert not any(r["id"] == content["id"] for r in withdrawn[collection])
    elif kind in {"flashcard", "quiz"}:
        row = next(r for r in withdrawn[collection] if r["id"] == content["id"])
        source = next(s for s in withdrawn["sources"] if s["id"] == row["source_id"])
        assert source["review_status"] == "deprecated"
    else:
        assert (
            next(r for r in withdrawn[collection] if r["id"] == content["id"])["review_status"]
            == "deprecated"
        )


def test_registration_is_idempotent_and_preserves_existing_reference_records(client, editors):
    _author, headers, _ = editors
    me = client.get("/api/v1/admin/me", headers=headers).json()
    with client.app.state.session_factory() as db:
        before = {
            m.__tablename__: db.scalar(select(func.count()).select_from(m))
            for m in [LearningLesson, Flashcard, MedicalTerm]
        }
        service = ReferencePublicationService(db)
        count = service.register_existing(UUID(me["user_id"]))
        assert count > 0
        db.commit()
        assert service.register_existing(UUID(me["user_id"])) == 0
        db.commit()
        after = {
            m.__tablename__: db.scalar(select(func.count()).select_from(m))
            for m in [LearningLesson, Flashcard, MedicalTerm]
        }
        assert after == before
        assert db.scalar(select(func.count()).select_from(GovernedContent)) == count + 1
    records = client.get(
        "/api/v1/admin/content?content_type=lesson&limit=100", headers=headers
    ).json()
    assert len(records) == before["learning_lessons"]
    assert all(row["content_type"] == "lesson" for row in records)
    document = client.get("/api/v1/content/dataset").json()
    assert len(document["lessons"]) == before["learning_lessons"]
    assert document["production_approved"] is False


def test_single_admin_approval_is_explicit_development_only_and_audited(client, editors):
    _, author, _ = editors
    _, content = fixture("lesson")
    stable_id = "lesson.local-review"
    assert save(client, author, stable_id, "lesson", content).status_code == 201
    assert action(client, author, stable_id, "submit_review").status_code == 200
    assert action(client, author, stable_id, "approve").status_code == 409
    settings = client.app.state.settings
    settings.admin_allow_local_self_review = True
    # Enabling the option in testing/production is insufficient: development is required.
    assert action(client, author, stable_id, "approve").status_code == 409
    settings.environment = "development"
    assert (
        client.get("/api/v1/admin/me", headers=author).json()["local_self_review_allowed"] is True
    )
    assert action(client, author, stable_id, "approve").status_code == 200
    assert action(client, author, stable_id, "publish").status_code == 200
    assert client.get("/api/v1/content/dataset").json()["production_approved"] is False
    with client.app.state.session_factory() as db:
        assert (
            db.scalar(select(AuditEvent).where(AuditEvent.action == "content.local_self_review"))
            is not None
        )


def test_invalid_reference_and_duplicate_editorial_identity_are_rejected(client, editors):
    _, author, _ = editors
    _, content = fixture("lesson")
    content["source_id"] = "missing-source"
    assert save(client, author, "lesson.invalid-source", "lesson", content).status_code == 400
    _, content = fixture("lesson")
    assert save(client, author, "lesson.original", "lesson", content).status_code == 201
    assert save(client, author, "lesson.duplicate", "lesson", content).status_code == 400
    assert client.get("/api/v1/content/dataset").status_code == 404


def test_publication_preserves_previous_independent_updates(client, editors):
    _, author, reviewer = editors
    for kind in ["lesson", "flashcard"]:
        _, content = fixture(kind)
        stable_id = kind + ".combined"
        assert save(client, author, stable_id, kind, content).status_code == 201
        for name, headers in [
            ("submit_review", author),
            ("approve", reviewer),
            ("publish", reviewer),
        ]:
            assert action(client, headers, stable_id, name).status_code == 200
    document = client.get("/api/v1/content/dataset").json()
    assert any(row["id"] == "publication-fixture-lesson" for row in document["lessons"])
    assert any(row["id"] == "publication-fixture-flashcard" for row in document["flashcards"])


def test_new_quiz_publication_respects_database_foreign_keys(client, editors):
    _, author, reviewer = editors
    engine = client.app.state.engine
    # The browser and PostgreSQL enforce foreign keys; the default in-memory
    # fixture does not. Exercise actual parent/child insertion with enforcement.
    with engine.connect() as connection:
        connection.exec_driver_sql("PRAGMA foreign_keys=ON")
        connection.commit()
    try:
        _, content = fixture("quiz")
        stable_id = "quiz.new-with-constraints"
        assert save(client, author, stable_id, "quiz", content).status_code == 201
        for name, headers in [
            ("submit_review", author),
            ("approve", reviewer),
            ("publish", reviewer),
        ]:
            response = action(client, headers, stable_id, name)
            assert response.status_code == 200, response.text
        document = client.get("/api/v1/content/dataset").json()
        published = next(r for r in document["quiz_questions"] if r["id"] == content["id"])
        assert published["options"] == content["options"]
    finally:
        with engine.connect() as connection:
            connection.exec_driver_sql("PRAGMA foreign_keys=OFF")
            connection.commit()
