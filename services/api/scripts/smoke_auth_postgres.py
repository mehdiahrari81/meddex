"""Verify real HTTP sessions and PostgreSQL hashing, then remove this run's QA account."""

import secrets

import httpx
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.core.security import verify_password
from app.db.session import create_database_engine
from app.models import User

settings = Settings()
engine = create_database_engine(settings)
email = f"auth-qa-{secrets.token_hex(12)}@example.com"
password = "Verification!123" + secrets.token_hex(10)
user_id = None
try:
    with httpx.Client(base_url="http://127.0.0.1:8000/api/v1/", timeout=30) as client:
        created = client.post(
            "auth/register",
            json={
                "email": email,
                "password": password,
                "display_name": "Temporary automated QA account",
            },
        )
        assert created.status_code == 201
        tokens = created.json()
        user_id = tokens["user_id"]
        with Session(engine) as db:
            user = db.scalar(select(User).where(User.email == email))
            assert user and user.password_hash.startswith("$argon2id$")
            assert verify_password(password, user.password_hash)
        login = client.post("auth/login", json={"email": email, "password": password})
        assert login.status_code == 200
        assert (
            client.post("auth/login", json={"email": email, "password": "wrong"}).status_code == 401
        )
        client.headers["Authorization"] = "Bearer " + tokens["access_token"]
        assert client.get("users/me").json()["email"] == email
        refresh = client.post("auth/refresh", json={"refresh_token": tokens["refresh_token"]})
        assert refresh.status_code == 200
        client.headers["Authorization"] = "Bearer " + refresh.json()["access_token"]
        assert client.post("auth/logout").status_code == 204
        assert client.get("users/me").status_code == 401
        assert (
            client.post(
                "auth/refresh", json={"refresh_token": refresh.json()["refresh_token"]}
            ).status_code
            == 401
        )
        # Simulate a new client process using the second persisted session.
        with httpx.Client(
            base_url=str(client.base_url),
            timeout=30,
            headers={"Authorization": "Bearer " + login.json()["access_token"]},
        ) as restored:
            assert restored.get("users/me").json()["id"] == user_id
        print(
            "PASS: register, Argon2id database hash, login, invalid credentials, refresh, "
            "logout, revoked-session rejection, persisted session in a new HTTP client"
        )
finally:
    with Session(engine) as db:
        user = db.scalar(select(User).where(User.email == email))
        if user:
            db.delete(user)
            db.commit()
    engine.dispose()
