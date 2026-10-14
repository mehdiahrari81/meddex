# Admin security

Admin tokens use a separate JWT audience and backend-created `AuthSession`, short configured lifetime, inactivity revocation, and membership lookup on every request. Role names are labels; every endpoint checks granular permissions. Mobile tokens cannot call admin routes and admin tokens cannot call user routes.

The Next.js app keeps the token in an HttpOnly, Secure, SameSite=Strict cookie, calls FastAPI only from server code, uses Server Actions (same-origin protections), CSP/frame/referrer/content-type/permissions headers, and permission-filtered navigation. Backend enforcement remains authoritative. Logout revokes the server session then removes the cookie.

Production settings refuse startup unless admin MFA is required. TOTP secrets are encrypted at rest; there is no default account, password, or automatic enrollment. Session/flag/publish/import/report destructive actions require explicit or typed confirmation and create audit events. Admin user support exposes only minimum account metadata, not tokens, prescriptions, images, or AI messages.
