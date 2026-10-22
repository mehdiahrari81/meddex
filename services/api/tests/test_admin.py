import hashlib
import hmac
import struct
import time

from fastapi.testclient import TestClient
from sqlalchemy import select

from app.core.security import hash_password
from app.models import (
    AdminMembership,
    AdminRole,
    AuditEvent,
    GovernanceReport,
    GovernedContentRevision,
    MedicationIdentity,
    MedicationProviderMapping,
    MedicationResolution,
    User,
    UserProfile,
)


def _admin(client: TestClient, role: str, email: str) -> dict[str, str]:
    factory = client.app.state.session_factory
    with factory() as db:
        user = User(
            email=email,
            password_hash=hash_password("SecurePassword!123"),
            profile=UserProfile(display_name="Admin"),
        )
        db.add(user)
        db.flush()
        role_model = db.scalar(select(AdminRole).where(AdminRole.name == role))
        if role_model is None:
            role_model = AdminRole(name=role, description=role)
            db.add(role_model)
            db.flush()
        db.add(AdminMembership(user_id=user.id, role_id=role_model.id, active=True))
        db.commit()
    login = client.post(
        "/api/v1/admin/auth/login",
        json={"email": email, "password": "SecurePassword!123", "mfa_code": None},
    )
    assert login.status_code == 200
    return login.json()


def _headers(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def test_non_admin_token_cannot_access_admin(
    client: TestClient, registered: dict[str, str]
) -> None:
    response = client.get("/api/v1/admin/me", headers=_headers(registered["access_token"]))
    assert response.status_code == 401


def test_admin_permissions_and_cross_role_denial(client: TestClient) -> None:
    editor = _admin(client, "CONTENT_EDITOR", "editor@example.com")
    assert "content.edit" in editor["permissions"]
    response = client.get("/api/v1/admin/audit", headers=_headers(editor["access_token"]))
    assert response.status_code == 403


def test_content_version_review_publish_and_audit(client: TestClient) -> None:

    editor = _admin(client, "CONTENT_EDITOR", "editor2@example.com")
    reviewer = _admin(client, "CONTENT_REVIEWER", "reviewer@example.com")
    create = client.post(
        "/api/v1/admin/content",
        headers=_headers(editor["access_token"]),
        json={
            "stable_id": "term.safe",
            "content_type": "terminology",
            "content": __import__(
                "tests.test_reference_releases", fromlist=["_document"]
            )._document()["terms"][0],
            "source_metadata": {"provider": "reviewed"},
            "change_reason": "Initial reviewed term",
        },
    )
    assert create.status_code == 201
    submit = client.post(
        "/api/v1/admin/content/term.safe/workflow",
        headers=_headers(editor["access_token"]),
        json={"action": "submit_review", "reason": "Ready for review"},
    )
    assert submit.json()["lifecycle_state"] == "in_review"
    approve = client.post(
        "/api/v1/admin/content/term.safe/workflow",
        headers=_headers(reviewer["access_token"]),
        json={"action": "approve", "reason": "Source checked"},
    )
    assert approve.json()["lifecycle_state"] == "approved"
    publish = client.post(
        "/api/v1/admin/content/term.safe/workflow",
        headers=_headers(reviewer["access_token"]),
        json={"action": "publish", "reason": "Release", "confirmation": "term.safe"},
    )
    assert publish.json()["published_revision"] == 1
    factory = client.app.state.session_factory
    with factory() as db:
        assert len(db.scalars(select(GovernedContentRevision)).all()) == 2
        assert len(db.scalars(select(AuditEvent)).all()) >= 4


def test_drap_import_dry_run_rejects_bad_data_and_requires_confirmation(
    client: TestClient,
) -> None:
    admin = _admin(client, "SUPER_ADMIN", "super@example.com")
    headers = _headers(admin["access_token"])
    dry_run = client.post(
        "/api/v1/admin/imports/dry-run",
        headers=headers,
        json={
            "dataset_type": "drap_products",
            "source_name": "Approved DRAP export",
            "source_version": "2026-08-01",
            "records": [
                {
                    "registration_id": "PK-REG-1",
                    "brand_name": "Imported Product",
                    "generic_name": "ingredient a / ingredient b",
                    "dosage_form": "tablet",
                    "ingredients": [
                        {"name": "ingredient a", "value": "500", "unit": "mg"},
                        {"name": "ingredient b", "value": "125", "unit": "mg"},
                    ],
                    "barcode": "1234567890123",
                }
            ],
        },
    )
    assert dry_run.status_code == 201
    job = dry_run.json()
    assert job["report"]["added"] == 1
    denied = client.post(
        f"/api/v1/admin/imports/{job['id']}/apply",
        headers=headers,
        json={"confirmation": "wrong"},
    )
    assert denied.status_code == 409
    applied = client.post(
        f"/api/v1/admin/imports/{job['id']}/apply",
        headers=headers,
        json={"confirmation": job["id"]},
    )
    assert applied.status_code == 200
    barcode = client.post(
        "/api/v1/medication-intelligence/barcodes/resolve",
        headers=_headers(admin["access_token"]),
        json={"value": "1234567890123"},
    )
    # Admin tokens are deliberately not mobile tokens.
    assert barcode.status_code == 401


def test_admin_session_revocation(client: TestClient) -> None:
    admin = _admin(client, "SUPER_ADMIN", "sessions@example.com")
    headers = _headers(admin["access_token"])
    revoke = client.post(f"/api/v1/admin/sessions/{admin['session_id']}/revoke", headers=headers)
    assert revoke.status_code == 204
    assert client.get("/api/v1/admin/me", headers=headers).status_code == 401


def test_csv_import_updates_existing_identity_and_preserves_concentration(
    client: TestClient,
) -> None:
    admin = _admin(client, "SUPER_ADMIN", "csv@example.com")
    headers = _headers(admin["access_token"])
    for version, brand in (("v1", "Original"), ("v2", "Updated")):
        response = client.post(
            "/api/v1/admin/imports/drap/upload",
            headers=headers,
            data={"source_name": "Reviewed test dataset", "source_version": version},
            files={
                "file": (
                    "products.csv",
                    (
                        "Registration Number,Brand Name,Composition,Dosage Form\n"
                        f"PK-TEST,{brand},Ingredient 120mg/5ml,suspension\n"
                    ).encode(),
                    "text/csv",
                )
            },
        )
        assert response.status_code == 201
        job = response.json()
        assert job["report"]["added" if version == "v1" else "updated"] == 1
        applied = client.post(
            f"/api/v1/admin/imports/{job['id']}/apply",
            headers=headers,
            json={"confirmation": job["id"]},
        )
        assert applied.status_code == 200
    with client.app.state.session_factory() as db:
        identity = db.scalar(select(MedicationIdentity))
        assert identity.canonical_display_name == "Updated"
        assert len(identity.identifiers) == 1
        assert identity.ingredients[0].numerator_unit == "mg"
        assert identity.ingredients[0].denominator_value == "5"
        assert identity.ingredients[0].denominator_unit == "ml"
        assert db.scalar(select(MedicationProviderMapping)).provider_version == "v2"
    unchanged = client.post(
        "/api/v1/admin/imports/drap/upload",
        headers=headers,
        data={"source_name": "Reviewed test dataset", "source_version": "v2"},
        files={
            "file": (
                "products.csv",
                (
                    b"Registration Number,Brand Name,Composition,Dosage Form\n"
                    b"PK-TEST,Updated,Ingredient 120mg/5ml,suspension\n"
                ),
                "text/csv",
            )
        },
    )
    assert unchanged.status_code == 201
    assert unchanged.json()["report"]["unchanged"] == 1


def test_csv_import_enforces_size_and_rejects_malformed_files(client: TestClient) -> None:
    admin = _admin(client, "SUPER_ADMIN", "csv-limit@example.com")
    headers = _headers(admin["access_token"])
    client.app.state.settings.max_import_bytes = 128
    for content, expected in (
        (b"x" * 129, 413),
        (b"\xff\xfe", 400),
        (b'Registration Number,Brand Name\n"unterminated', 400),
    ):
        response = client.post(
            "/api/v1/admin/imports/drap/upload",
            headers=headers,
            data={"source_name": "Reviewed test dataset", "source_version": "v1"},
            files={"file": ("products.csv", content, "text/csv")},
        )
        assert response.status_code == expected


def test_admin_mfa_accepts_only_encrypted_configured_totp(client: TestClient) -> None:
    from app.services.admin_auth import AdminAuthService

    secret = b"test-totp-secret-kept-outside-persistence"
    factory = client.app.state.session_factory
    with factory() as db:
        user = User(
            email="mfa@example.com",
            password_hash=hash_password("SecurePassword!123"),
            profile=UserProfile(display_name="MFA Admin"),
        )
        role = db.scalar(select(AdminRole).where(AdminRole.name == "SUPER_ADMIN"))
        assert role is not None
        db.add(user)
        db.flush()
        encrypted = AdminAuthService(db, client.app.state.settings).encrypt_mfa_secret(secret)
        assert secret not in encrypted
        db.add(
            AdminMembership(
                user_id=user.id,
                role_id=role.id,
                active=True,
                mfa_enabled=True,
                mfa_secret_encrypted=encrypted,
            )
        )
        db.commit()
    counter = int(time.time()) // 30
    digest = hmac.new(secret, struct.pack(">Q", counter), hashlib.sha1).digest()
    index = digest[-1] & 0x0F
    code = f"{(struct.unpack('>I', digest[index : index + 4])[0] & 0x7FFFFFFF) % 1_000_000:06d}"
    denied = client.post(
        "/api/v1/admin/auth/login",
        json={"email": "mfa@example.com", "password": "SecurePassword!123", "mfa_code": "000000"},
    )
    assert denied.status_code == 401
    allowed = client.post(
        "/api/v1/admin/auth/login",
        json={"email": "mfa@example.com", "password": "SecurePassword!123", "mfa_code": code},
    )
    assert allowed.status_code == 200


def test_feature_flag_requires_revision_and_typed_confirmation(client: TestClient) -> None:
    admin = _admin(client, "SUPER_ADMIN", "flags@example.com")
    headers = _headers(admin["access_token"])
    flags = client.get("/api/v1/admin/feature-flags", headers=headers).json()
    ai = next(item for item in flags if item["key"] == "ai_assistant")
    denied = client.put(
        "/api/v1/admin/feature-flags/ai_assistant",
        headers=headers,
        json={"enabled": True, "expected_revision": ai["revision"], "confirmation": "wrong"},
    )
    assert denied.status_code == 409
    updated = client.put(
        "/api/v1/admin/feature-flags/ai_assistant",
        headers=headers,
        json={
            "enabled": True,
            "expected_revision": ai["revision"],
            "confirmation": "ai_assistant",
        },
    )
    assert updated.status_code == 200
    assert updated.json()["enabled"] is True


def test_report_resolution_and_medication_annotation_are_audited(client: TestClient) -> None:
    admin = _admin(client, "SUPER_ADMIN", "review@example.com")
    headers = _headers(admin["access_token"])
    factory = client.app.state.session_factory
    with factory() as db:
        admin_user = db.scalar(select(User).where(User.email == "review@example.com"))
        assert admin_user is not None
        report = GovernanceReport(
            report_type="unsafe_ai",
            target_type="ai_answer",
            target_id="redacted-answer",
            reason="unsafe",
            redacted_context={"has_note": True},
            status="open",
        )
        resolution = MedicationResolution(
            user_id=admin_user.id,
            input_origin="search",
            raw_confirmed_value="unresolved",
            normalized_search_string="unresolved",
            state="no_trusted_match",
            candidates=[],
            provider_failures=[],
        )
        db.add_all([report, resolution])
        db.commit()
        report_id = str(report.id)
        resolution_id = str(resolution.id)
    reviewed = client.post(
        f"/api/v1/admin/reports/{report_id}/workflow",
        headers=headers,
        json={
            "status": "resolved",
            "resolution_note": "Reviewed source and safety classification.",
            "confirmation": report_id,
        },
    )
    assert reviewed.status_code == 200
    annotated = client.post(
        f"/api/v1/admin/resolution-review/{resolution_id}/annotate",
        headers=headers,
        json={
            "note": "No registry identity available; do not override.",
            "review_status": "reviewed_no_override",
        },
    )
    assert annotated.status_code == 200
    with factory() as db:
        actions = {item.action for item in db.scalars(select(AuditEvent)).all()}
        assert "report.workflow" in actions
        assert "medication_resolution.annotate" in actions
