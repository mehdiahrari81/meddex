"""Exercise CPU OCR over authenticated HTTP, deleting only this temporary QA account."""

import secrets
import time

import httpx
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.db.session import create_database_engine
from app.models import User

engine = create_database_engine(Settings())
email = f"ocr-qa-{secrets.token_hex(12)}@example.com"
try:
    with httpx.Client(base_url="http://127.0.0.1:8000/api/v1/", timeout=120) as client:
        account = client.post(
            "auth/register",
            json={
                "email": email,
                "password": "QaVerification!123" + secrets.token_hex(8),
                "display_name": "Temporary OCR QA account",
            },
        )
        account.raise_for_status()
        client.headers["Authorization"] = "Bearer " + account.json()["access_token"]
        url = (
            "https://huggingface.co/datasets/hf-internal-testing/fixtures_ocr/"
            "resolve/main/iam_picture.jpeg"
        )
        image = httpx.get(url, timeout=30, follow_redirects=True)
        image.raise_for_status()
        for label in ("cold", "warm"):
            start = time.perf_counter()
            result = client.post(
                "prescription-ocr/handwriting",
                content=image.content,
                headers={"Content-Type": "image/jpeg"},
            )
            result.raise_for_status()
            payload = result.json()
            assert payload["text"].lower() == "industry"
            assert payload["requires_review"] is True
            assert all(line["confidence"] is None for line in payload["lines"])
            assert result.headers["Cache-Control"] == "no-store"
            print(
                f"PASS authenticated {label} CPU OCR: {time.perf_counter() - start:.3f}s; "
                "public handwriting recognized; review required",
                flush=True,
            )
finally:
    with Session(engine) as db:
        user = db.scalar(select(User).where(User.email == email))
        if user:
            db.delete(user)
            db.commit()
    engine.dispose()
