from typing import Any


class AppException(Exception):
    def __init__(
        self,
        code: str,
        message: str,
        *,
        status_code: int,
        details: dict[str, Any] | None = None,
    ) -> None:
        super().__init__(message)
        self.code = code
        self.message = message
        self.status_code = status_code
        self.details = details


class InvalidCredentialsError(AppException):
    def __init__(self) -> None:
        super().__init__(
            "invalid_credentials",
            "The email or password is incorrect.",
            status_code=401,
        )


class SessionExpiredError(AppException):
    def __init__(self) -> None:
        super().__init__(
            "session_expired",
            "The session is invalid or has expired.",
            status_code=401,
        )


class ConflictError(AppException):
    def __init__(self, code: str, message: str) -> None:
        super().__init__(code, message, status_code=409)
