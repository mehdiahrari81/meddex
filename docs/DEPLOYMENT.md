# Deployment

Development may use `docker compose`; staging and production require external PostgreSQL, unique secret/signing/model/provider credentials from a secret manager, TLS, trusted origins, production MFA, ingress/shared rate limiting for multiple API workers, encrypted backup scheduling, central logs/metrics, and an approved DRAP dataset process.

The API/admin Dockerfiles are deterministic from locks, non-root, health-checked, and use graceful SIGTERM handling. Run `alembic upgrade head` as a single controlled pre-deploy job, then start replicas and require readiness before traffic. Do not run concurrent migrations in every replica. Roll back the application image first; schema downgrades require reviewed backup/recovery planning and must never destroy user data casually.

Mobile production builds require `APP_ENV=production` and an HTTPS `API_BASE_URL`. Admin must omit `ADMIN_COOKIE_SECURE=false`. AI remains disabled unless both server configuration and `ai_assistant` feature flag are present. Interaction checking remains disabled until a validated licensed provider adapter exists.

CI builds/tests only. The dispatch release workflow builds immutable images in a protected staging/production environment and intentionally leaves registry/deployment commands environment-specific behind approval.
