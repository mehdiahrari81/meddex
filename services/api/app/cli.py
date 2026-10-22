"""Local operator tools. Administrator provisioning is always interactive."""

import argparse
import base64
import getpass
import json
import secrets
from pathlib import Path
from urllib.parse import urlencode

from pydantic import ValidationError
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.core.security import hash_password, verify_password
from app.db.session import create_database_engine
from app.models import (
    AdminMembership,
    AdminRole,
    AdminRolePermission,
    AuditEvent,
    ContentVersion,
    FeatureFlag,
    User,
    UserProfile,
)
from app.schemas.auth import RegisterRequest
from app.services.admin_auth import AdminAuthService
from app.services.content_import import ContentImporter
from app.services.demo_data import seed_demo_data
from app.services.medication_reference import import_medication_reference


def provision_admin(
    db: Session,
    settings: Settings,
    *,
    email: str,
    password: str,
    display_name: str,
    role_name: str,
    mfa_secret: bytes | None = None,
) -> User:
    try:
        validated = RegisterRequest(email=email, password=password, display_name=display_name)
    except ValidationError:
        raise ValueError(
            "Enter a valid email/name and a password meeting the stated requirements."
        ) from None
    normalized_email = str(validated.email).lower()
    role = db.scalar(select(AdminRole).where(AdminRole.name == role_name))
    if role is None:
        raise ValueError("Unknown role. Apply database migrations before provisioning.")
    if settings.admin_mfa_required and mfa_secret is None:
        raise ValueError("MFA enrollment is required in this environment.")
    user = db.scalar(select(User).where(User.email == normalized_email))
    if user is None:
        user = User(
            email=normalized_email,
            password_hash=hash_password(password),
            profile=UserProfile(display_name=display_name.strip()),
        )
        db.add(user)
        db.flush()
    elif not user.is_active or not verify_password(password, user.password_hash):
        raise ValueError("Existing account credentials were not accepted.")
    if db.scalar(select(AdminMembership).where(AdminMembership.user_id == user.id)) is not None:
        raise ValueError("Account already has an administrative membership; no changes applied.")
    db.add(
        AdminMembership(
            user_id=user.id,
            role_id=role.id,
            active=True,
            mfa_enabled=mfa_secret is not None,
            mfa_secret_encrypted=(
                AdminAuthService(db, settings).encrypt_mfa_secret(mfa_secret)
                if mfa_secret is not None
                else None
            ),
        )
    )
    db.commit()
    return user


def main() -> None:
    parser = argparse.ArgumentParser(description="MediExplain operator tools")
    commands = parser.add_subparsers(dest="command", required=True)
    reference = commands.add_parser(
        "import-reference", help="Validate and install a reference dataset"
    )
    reference.add_argument("--path", type=Path, required=True)
    reference.add_argument("--if-empty", action="store_true", help="Seed only a fresh database")
    reference.add_argument(
        "--additive", action="store_true", help="Preserve existing learning records"
    )
    medicine = commands.add_parser(
        "import-medications", help="Install an attributed RxNorm snapshot"
    )
    medicine.add_argument("--path", type=Path, required=True)
    demo = commands.add_parser("seed-demo", help="Add labeled FYP demonstration data locally")
    demo.add_argument("--actor-email", required=True, help="Existing active administrator")
    demo.add_argument("--path", type=Path, required=True, help="Bundled development dataset")
    admin = commands.add_parser("provision-admin", help="Create a named administrative membership")
    admin.add_argument("--email", required=True)
    admin.add_argument("--name", required=True)
    admin.add_argument("--role", default="SUPER_ADMIN")
    admin.add_argument("--mfa", action="store_true", help="Enroll and verify an authenticator")
    commands.add_parser(
        "enable-ai", help="Enable the configured AI assistant with an operator audit event"
    )
    register = commands.add_parser(
        "register-reference-content", help="Register installed content in the editorial catalogue"
    )
    register.add_argument("--actor-email", required=True)
    args = parser.parse_args()
    settings = Settings()
    if args.command == "register-reference-content":
        from app.services.reference_publication import ReferencePublicationService

        engine = create_database_engine(settings)
        try:
            with Session(engine) as db:
                actor = db.scalar(
                    select(User)
                    .join(AdminMembership, AdminMembership.user_id == User.id)
                    .where(
                        User.email == args.actor_email.strip().lower(),
                        AdminMembership.active.is_(True),
                    )
                )
                if actor is None:
                    parser.error("An existing active administrator is required.")
                permissions = list(
                    db.scalars(
                        select(AdminRolePermission.permission_code)
                        .join(
                            AdminMembership, AdminMembership.role_id == AdminRolePermission.role_id
                        )
                        .where(AdminMembership.user_id == actor.id)
                    )
                )
                if not {"content.edit", "content.publish"}.issubset(permissions):
                    parser.error(
                        "Reference registration requires content.edit and content.publish."
                    )
                count = ReferencePublicationService(db).register_existing(actor.id)
                db.add(
                    AuditEvent(
                        actor_id=actor.id,
                        permission_context=permissions,
                        action="content.register_existing",
                        target_type="reference_catalogue",
                        target_id="reference.mobile",
                        request_id="operator-registration",
                        safe_metadata={"registered": count},
                    )
                )
                db.commit()
                print(
                    f"Registered {count} existing reference records; "
                    "source attribution and user data preserved."
                )
        finally:
            engine.dispose()
        return
    if args.command == "enable-ai":
        if settings.ai_provider == "disabled":
            parser.error("Configure an AI provider before enabling the assistant.")
        engine = create_database_engine(settings)
        try:
            with Session(engine) as db:
                flag = db.get(FeatureFlag, "ai_assistant")
                if flag is None:
                    parser.error("Apply migrations first.")
                if not flag.enabled:
                    flag.enabled = True
                    flag.revision += 1
                    db.add(
                        AuditEvent(
                            actor_id=None,
                            action="feature_flag.enable",
                            target_type="feature_flag",
                            target_id="ai_assistant",
                            request_id="operator-cli",
                            permission_context=["operator.cli"],
                            safe_metadata={
                                "provider": settings.ai_provider,
                                "revision": flag.revision,
                            },
                        )
                    )
                    db.commit()
                print("AI assistant enabled. Medical source and safety checks remain active.")
        finally:
            engine.dispose()
        return
    if args.command == "import-medications":
        engine = create_database_engine(settings)
        try:
            with Session(engine) as db:
                result = import_medication_reference(db, args.path)
                print(json.dumps(result, sort_keys=True))
        finally:
            engine.dispose()
        return
    if args.command == "seed-demo":
        if settings.environment not in {"development", "testing"}:
            parser.error("Demo data is restricted to development and testing.")
        engine = create_database_engine(settings)
        try:
            with Session(engine) as db:
                try:
                    result = seed_demo_data(
                        db, settings, args.actor_email, json.loads(args.path.read_text())
                    )
                except ValueError as error:
                    db.rollback()
                    parser.error(str(error))
                print(f"Demo records added: {json.dumps(result, sort_keys=True)}")
        finally:
            engine.dispose()
        return
    if args.command == "import-reference":
        engine = create_database_engine(settings)
        try:
            with Session(engine) as db:
                if (
                    args.if_empty
                    and db.get(ContentVersion, json.loads(args.path.read_text())["dataset_name"])
                    is not None
                ):
                    print("Existing reference release preserved.")
                    return
                importer = ContentImporter(db)
                report = importer.import_path(args.path, dry_run=True, additive=args.additive)
                if settings.environment == "production" and not report.production_approved:
                    parser.error("Production requires an approved reference dataset.")
                report = importer.import_path(args.path, additive=args.additive)
                print(
                    f"Reference {report.dataset_name} {report.dataset_version}: "
                    f"{report.terms} terms."
                )
        finally:
            engine.dispose()
        return
    password = getpass.getpass("Password (12-128 characters, upper/lowercase, number, symbol): ")
    if password != getpass.getpass("Confirm password: "):
        parser.error("Passwords do not match.")
    secret = None
    if args.mfa or settings.admin_mfa_required:
        secret = secrets.token_bytes(20)
        encoded = base64.b32encode(secret).decode().rstrip("=")
        print("Enroll this one-time secret in your authenticator; store it securely:")
        print(encoded)
        print(
            "otpauth://totp/MediExplain:"
            + args.email
            + "?"
            + urlencode(
                {
                    "secret": encoded,
                    "issuer": "MediExplain",
                    "digits": 6,
                    "period": 30,
                }
            )
        )
        if not AdminAuthService._verify_totp(secret, getpass.getpass("Authenticator code: ")):
            parser.error("MFA verification failed. No account was provisioned.")
    engine = create_database_engine(settings)
    try:
        with Session(engine) as db:
            try:
                provision_admin(
                    db,
                    settings,
                    email=args.email,
                    password=password,
                    display_name=args.name,
                    role_name=args.role,
                    mfa_secret=secret,
                )
            except ValueError as error:
                db.rollback()
                parser.error(str(error))
        print("Administrator provisioned. Sign in using the configured admin portal.")
    finally:
        engine.dispose()


if __name__ == "__main__":
    main()
