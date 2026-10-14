"""Explicit local-only SMTP/password-reset smoke check; no secrets are printed."""

import argparse
import re
import secrets
import time
from urllib.parse import urlparse

import httpx


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--api", default="http://127.0.0.1:8000/api/v1")
    parser.add_argument("--mail", default="http://127.0.0.1:8025")
    args = parser.parse_args()
    for url in (args.api, args.mail):
        if urlparse(url).hostname not in {"127.0.0.1", "localhost"}:
            parser.error("This smoke check accepts localhost services only.")
    email = f"local-verification-{secrets.token_hex(6)}@example.com"
    password = "Local-Test!1" + secrets.token_urlsafe(18)
    new_password = "Local-Test!2" + secrets.token_urlsafe(18)
    token: str | None = None
    message_id: str | None = None
    with (
        httpx.Client(base_url=args.api + "/", timeout=15) as api,
        httpx.Client(base_url=args.mail + "/", timeout=10) as mail,
    ):
        try:
            api.get("ready").raise_for_status()
            created = api.post(
                "auth/register",
                json={
                    "email": email,
                    "password": password,
                    "display_name": "Local verification",
                },
            )
            created.raise_for_status()
            token = created.json()["access_token"]
            old_token = token
            api.post("auth/password/forgot", json={"email": email}).raise_for_status()
            for _ in range(20):
                inbox = mail.get("api/v1/messages")
                inbox.raise_for_status()
                matching = [
                    message
                    for message in inbox.json()["messages"]
                    if any(recipient["Address"] == email for recipient in message["To"])
                ]
                if matching:
                    message_id = matching[0]["ID"]
                    break
                time.sleep(0.25)
            if message_id is None:
                raise RuntimeError("Password-reset email did not reach the local inbox.")
            message = mail.get(f"api/v1/message/{message_id}")
            message.raise_for_status()
            code = re.search(r"paste this code:\s+(\S+)", message.json()["Text"])
            if code is None:
                raise RuntimeError("Password-reset email did not contain a reset code.")
            reset = {"token": code[1], "new_password": new_password}
            api.post("auth/password/reset", json=reset).raise_for_status()
            assert (
                api.get("users/me", headers={"Authorization": f"Bearer {old_token}"}).status_code
                == 401
            )
            assert api.post("auth/password/reset", json=reset).status_code == 401
            assert (
                api.post("auth/login", json={"email": email, "password": password}).status_code
                == 401
            )
            login = api.post("auth/login", json={"email": email, "password": new_password})
            login.raise_for_status()
            token = login.json()["access_token"]
            print(
                "PASS: PostgreSQL auth, SMTP reset delivery, single use, "
                "password change, and revocation."
            )
        finally:
            if token:
                # A reset revokes the old token; obtain the new one if validation failed later.
                recovery = api.post("auth/login", json={"email": email, "password": new_password})
                if recovery.is_success:
                    token = recovery.json()["access_token"]
                deleted = api.delete("users/me", headers={"Authorization": f"Bearer {token}"})
                deleted.raise_for_status()
            if message_id:
                mail.request(
                    "DELETE", "api/v1/messages", json={"IDs": [message_id]}
                ).raise_for_status()


if __name__ == "__main__":
    main()
