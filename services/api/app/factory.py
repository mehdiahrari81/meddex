from typing import Any
from uuid import uuid4

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import Engine

from app.api.v1.router import api_router
from app.core.config import Settings, get_settings
from app.core.errors import AppException
from app.core.logging import configure_logging, get_logger
from app.core.middleware import (
    AuthenticationRateLimitMiddleware,
    InMemoryFixedWindowRateLimiter,
    RequestIdMiddleware,
    RequestMetrics,
    RequestMetricsMiddleware,
)
from app.db.session import create_database_engine, create_session_factory
from app.services.email import DevelopmentEmailSender, EmailSender, SmtpEmailSender


def create_app(
    settings: Settings | None = None,
    *,
    engine: Engine | None = None,
    email_sender: EmailSender | None = None,
) -> FastAPI:
    resolved_settings = settings or get_settings()
    configure_logging(resolved_settings.log_level)
    app = FastAPI(
        title=resolved_settings.app_name,
        version="1.0.0",
        description=("Secure, versioned MediExplain terminology, learning, and user-data API."),
        docs_url="/docs" if resolved_settings.environment != "production" else None,
        redoc_url="/redoc" if resolved_settings.environment != "production" else None,
    )
    app.state.settings = resolved_settings
    app.state.engine = engine or create_database_engine(resolved_settings)
    app.state.session_factory = create_session_factory(app.state.engine)
    app.state.email_sender = email_sender or (
        SmtpEmailSender(resolved_settings)
        if resolved_settings.smtp_host
        else DevelopmentEmailSender()
    )
    app.state.request_metrics = RequestMetrics()

    app.add_middleware(
        CORSMiddleware,
        allow_origins=resolved_settings.allowed_origins,
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type", "Idempotency-Key", "X-Request-ID"],
    )
    app.add_middleware(
        AuthenticationRateLimitMiddleware,
        limiter=InMemoryFixedWindowRateLimiter(resolved_settings.rate_limit_per_minute),
        api_prefix=resolved_settings.api_prefix,
    )
    app.add_middleware(RequestIdMiddleware)
    app.add_middleware(RequestMetricsMiddleware, metrics=app.state.request_metrics)

    @app.exception_handler(AppException)
    async def app_exception_handler(request: Request, error: AppException) -> JSONResponse:
        return _error_response(
            request,
            status_code=error.status_code,
            code=error.code,
            message=error.message,
            details=error.details,
        )

    @app.exception_handler(RequestValidationError)
    async def validation_exception_handler(
        request: Request, error: RequestValidationError
    ) -> JSONResponse:
        details = [
            {"field": ".".join(str(part) for part in item["loc"]), "type": item["type"]}
            for item in error.errors()
        ]
        return _error_response(
            request,
            status_code=422,
            code="validation_error",
            message="The request contains invalid fields.",
            details=details,
        )

    @app.exception_handler(Exception)
    async def unexpected_exception_handler(request: Request, error: Exception) -> JSONResponse:
        get_logger().exception("unhandled_request_error", error_type=type(error).__name__)
        return _error_response(
            request,
            status_code=500,
            code="server_error",
            message="An unexpected server error occurred.",
        )

    app.include_router(api_router, prefix=resolved_settings.api_prefix)
    return app


def _error_response(
    request: Request,
    *,
    status_code: int,
    code: str,
    message: str,
    details: Any = None,
) -> JSONResponse:
    request_id = getattr(request.state, "request_id", str(uuid4()))
    return JSONResponse(
        status_code=status_code,
        headers={"X-Request-ID": request_id},
        content={
            "error": {
                "code": code,
                "message": message,
                "request_id": request_id,
                "details": details,
            }
        },
    )
