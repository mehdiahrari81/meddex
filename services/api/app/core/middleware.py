import hashlib
import re
import threading
import time
from collections import defaultdict
from collections.abc import Awaitable, Callable
from uuid import uuid4

import structlog.contextvars
from fastapi import Request, Response
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware

REQUEST_ID_PATTERN = re.compile(r"^[A-Za-z0-9._-]{1,100}$")
IDENTIFIER_PATTERN = re.compile(
    r"/(?:[0-9a-f]{8}-[0-9a-f-]{27,}|[A-Za-z0-9_-]{18,})(?=/|$)", re.IGNORECASE
)


class RequestIdMiddleware(BaseHTTPMiddleware):
    async def dispatch(
        self, request: Request, call_next: Callable[[Request], Awaitable[Response]]
    ) -> Response:
        supplied = request.headers.get("X-Request-ID", "")
        request_id = supplied if REQUEST_ID_PATTERN.fullmatch(supplied) else str(uuid4())
        request.state.request_id = request_id
        structlog.contextvars.clear_contextvars()
        structlog.contextvars.bind_contextvars(request_id=request_id)
        response = await call_next(request)
        response.headers["X-Request-ID"] = request_id
        if "/auth" in request.url.path or "/prescription-ocr" in request.url.path:
            response.headers["Cache-Control"] = "no-store"
        return response


class RequestMetrics:
    """Bounded, process-local metrics adapter with no user/medical labels."""

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._started_at = time.time()
        self._requests = 0
        self._errors = 0
        self._latency_total_ms = 0.0
        self._by_route: dict[str, dict[str, float | int]] = {}

    def observe(self, method: str, path: str, status: int, latency_ms: float) -> None:
        safe_path = IDENTIFIER_PATTERN.sub("/:id", path)
        key = f"{method} {safe_path[:180]}"
        with self._lock:
            self._requests += 1
            if status >= 500:
                self._errors += 1
            self._latency_total_ms += latency_ms
            values = self._by_route.setdefault(
                key, {"requests": 0, "server_errors": 0, "latency_total_ms": 0.0}
            )
            values["requests"] = int(values["requests"]) + 1
            values["server_errors"] = int(values["server_errors"]) + int(status >= 500)
            values["latency_total_ms"] = float(values["latency_total_ms"]) + latency_ms
            if len(self._by_route) > 500:
                self._by_route.pop(next(iter(self._by_route)))

    def snapshot(self) -> dict[str, object]:
        with self._lock:
            routes = {
                key: {
                    "requests": value["requests"],
                    "server_errors": value["server_errors"],
                    "average_latency_ms": round(
                        float(value["latency_total_ms"]) / max(1, int(value["requests"])), 2
                    ),
                }
                for key, value in self._by_route.items()
            }
            return {
                "uptime_seconds": int(time.time() - self._started_at),
                "requests": self._requests,
                "server_errors": self._errors,
                "average_latency_ms": round(self._latency_total_ms / max(1, self._requests), 2),
                "routes": routes,
            }


class RequestMetricsMiddleware(BaseHTTPMiddleware):
    def __init__(self, app: object, metrics: RequestMetrics) -> None:
        super().__init__(app)  # type: ignore[arg-type]
        self.metrics = metrics

    async def dispatch(
        self, request: Request, call_next: Callable[[Request], Awaitable[Response]]
    ) -> Response:
        started = time.monotonic()
        status_code = 500
        try:
            response = await call_next(request)
            status_code = response.status_code
            return response
        finally:
            self.metrics.observe(
                request.method,
                request.url.path,
                status_code,
                (time.monotonic() - started) * 1000,
            )


class RateLimiter:
    def allow(self, key: str) -> tuple[bool, int]:
        raise NotImplementedError


class InMemoryFixedWindowRateLimiter(RateLimiter):
    """Single-process development adapter; replace with a shared store in production."""

    def __init__(self, limit: int, window_seconds: int = 60) -> None:
        self.limit = limit
        self.window_seconds = window_seconds
        self._buckets: dict[str, tuple[int, int]] = defaultdict(lambda: (0, 0))
        self._lock = threading.Lock()

    def allow(self, key: str) -> tuple[bool, int]:
        window = int(time.time()) // self.window_seconds
        with self._lock:
            bucket_window, count = self._buckets[key]
            count = count + 1 if bucket_window == window else 1
            self._buckets[key] = (window, count)
            if len(self._buckets) > 10_000:
                self._buckets = {
                    item_key: value
                    for item_key, value in self._buckets.items()
                    if value[0] >= window - 1
                }
        retry_after = self.window_seconds - (int(time.time()) % self.window_seconds)
        return count <= self.limit, retry_after


class AuthenticationRateLimitMiddleware(BaseHTTPMiddleware):
    def __init__(self, app: object, limiter: RateLimiter, api_prefix: str) -> None:
        super().__init__(app)  # type: ignore[arg-type]
        self.limiter = limiter
        self.rate_limited_paths = (
            f"{api_prefix}/auth",
            f"{api_prefix}/admin/auth",
            f"{api_prefix}/terms/search",
            f"{api_prefix}/reports/content",
            f"{api_prefix}/medication-intelligence/resolutions",
            f"{api_prefix}/medication-intelligence/barcodes",
            f"{api_prefix}/medication-intelligence/ai",
            f"{api_prefix}/medication-intelligence/reports",
            f"{api_prefix}/admin/imports",
            f"{api_prefix}/prescription-ocr",
        )

    async def dispatch(
        self, request: Request, call_next: Callable[[Request], Awaitable[Response]]
    ) -> Response:
        if any(request.url.path.startswith(path) for path in self.rate_limited_paths):
            client = request.client.host if request.client else "unknown"
            authorization = request.headers.get("Authorization", "")
            identity_key = (
                hashlib.sha256(authorization.encode()).hexdigest()[:16]
                if authorization and "/auth" not in request.url.path
                else client
            )
            allowed, retry_after = self.limiter.allow(f"{identity_key}:{request.url.path}")
            if not allowed:
                request_id = getattr(request.state, "request_id", str(uuid4()))
                return JSONResponse(
                    status_code=429,
                    headers={"Retry-After": str(retry_after), "X-Request-ID": request_id},
                    content={
                        "error": {
                            "code": "rate_limited",
                            "message": "Too many requests. Try again later.",
                            "request_id": request_id,
                            "details": None,
                        }
                    },
                )
        return await call_next(request)
