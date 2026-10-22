"""Replay owner-scoped HTTP scenarios against a running localhost API.

Uses real HTTP/PostgreSQL, paces requests below the development rate limit,
and deletes only the synthetic accounts created by this run.
"""

import argparse
import inspect
import secrets
import time
from collections.abc import Callable
from typing import Any
from urllib.parse import urlparse

import httpx

from tests import (
    test_medications,
    test_module2,
    test_prescriptions,
    test_profile_and_consent,
    test_sessions,
)


class LiveClient:
    def __init__(self, base_url: str, expected_content_version: str | None = None) -> None:
        self.http = httpx.Client(base_url=base_url, timeout=20)
        self.accounts: list[dict[str, str]] = []
        self.aliases: dict[str, str] = {}
        self.expected_content_version = expected_content_version

    def request(self, method: str, path: str, **kwargs: Any) -> httpx.Response:
        time.sleep(0.9)
        payload = kwargs.get("json")
        registration = path.endswith("/auth/register")
        if registration and isinstance(payload, dict):
            original = payload["email"]
            payload = {**payload, "email": f"live-smoke-{secrets.token_hex(8)}@example.com"}
            self.aliases[original] = payload["email"]
            kwargs["json"] = payload
        elif path.endswith("/auth/login") and isinstance(payload, dict):
            kwargs["json"] = {
                **payload,
                "email": self.aliases.get(payload["email"], payload["email"]),
            }
        response = self.http.request(method, path, **kwargs)
        if registration and response.status_code == 201:
            self.accounts.append({"email": payload["email"], "password": payload["password"]})
        return response

    def __getattr__(self, name: str) -> Callable[..., httpx.Response]:
        if name not in {"get", "post", "put", "patch", "delete"}:
            raise AttributeError(name)
        return lambda path, **kwargs: self.request(name.upper(), path, **kwargs)

    def cleanup(self) -> None:
        try:
            for account in reversed(self.accounts):
                login = self.request("POST", "/api/v1/auth/login", json=account)
                if login.status_code == 401:
                    # Account-deletion scenarios intentionally remove the account.
                    continue
                login.raise_for_status()
                self.request(
                    "DELETE",
                    "/api/v1/users/me",
                    headers={
                        "Authorization": f"Bearer {login.json()['access_token']}",
                    },
                ).raise_for_status()
        finally:
            self.http.close()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", default="http://127.0.0.1:18000")
    parser.add_argument("--expected-content-version", help="Expected installed reference version")
    args = parser.parse_args()
    if urlparse(args.url).hostname not in {"127.0.0.1", "localhost"}:
        parser.error("This smoke test accepts localhost only.")
    scenarios = []
    for module in (
        test_profile_and_consent,
        test_prescriptions,
        test_medications,
        test_module2,
        test_sessions,
    ):
        for name, function in inspect.getmembers(module, inspect.isfunction):
            if (
                not name.startswith("test_")
                or name == "test_content_report_validation_and_submission"
            ):
                continue
            if not set(inspect.signature(function).parameters) <= {"client", "registered"}:
                continue
            if "client.app" in inspect.getsource(function):
                continue
            scenarios.append((name, function))
    failures = []
    for index, (name, function) in enumerate(scenarios, start=1):
        client = LiveClient(args.url, args.expected_content_version)
        try:
            arguments: dict[str, Any] = {"client": client}
            if "registered" in inspect.signature(function).parameters:
                response = client.post(
                    "/api/v1/auth/register",
                    json={
                        "email": "person@example.com",
                        "password": "SecurePassword!123",
                        "display_name": "Live smoke verification",
                    },
                )
                response.raise_for_status()
                arguments["registered"] = response.json()
            function(**arguments)
            print(f"PASS {index}/{len(scenarios)}: {name}", flush=True)
        except Exception as error:
            failures.append(name)
            print(f"FAIL {index}/{len(scenarios)}: {name} ({type(error).__name__})", flush=True)
        finally:
            client.cleanup()
    print(
        f"Live API: {len(scenarios) - len(failures)}/{len(scenarios)} scenarios passed.", flush=True
    )
    if failures:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
