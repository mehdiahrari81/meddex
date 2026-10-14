# Security

Controls include Argon2 password hashing, short signed JWTs with issuer/audience/session binding, rotating hashed refresh tokens, revocation, owner-scoped queries, strict Pydantic schemas, SQLAlchemy parameterization, explicit CORS, request IDs, bounded high-risk endpoint limits, CSP/secure cookies, private file storage, server-only secrets, and production configuration fail-closed validation.

The API never logs request bodies. Structured log keys matching password/token/auth/cookie/prescription/medication are redacted. Metrics use bounded normalized route labels with identifiers replaced and never include bodies/query text. AI/provider errors are safe codes.

Mobile follows MASVS-oriented boundaries: no production secret in the binary, secure credential vault, HTTPS required in production, private files, Android backup disabled, explicit runtime permissions, biometric lock option, no direct database access, local OCR, and no medical-text analytics.

Rate limiting covers auth/reset, admin login, terminology/medicine search, barcode, AI, reports, and imports. The in-memory adapter is for a single process; multi-instance production must provide ingress/shared distributed rate limiting as documented in deployment.
