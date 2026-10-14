# Production checklist

- [ ] Provision managed PostgreSQL, TLS, secrets, strong signing key, and distinct staging/production origins.
- [ ] Provision named administrators through a controlled process; require/enroll encrypted MFA; verify session revocation.
- [ ] Configure authenticated SMTP with TLS and a verified sender domain; test delivery, expiry, single-use reset codes, and session revocation. Development Mailpit is an inbox capture service.
- [ ] Select central logging/metrics/alerting and shared ingress/distributed rate limiting.
- [ ] Approve source licensing/attribution and a DRAP dataset/import review procedure.
- [ ] Publish a validated complete reference dataset through independent editorial review, with a unique version and production approval. Verify download/update on mobile and preserve the previous cache on failure. The bundled dataset is development-only.
- [ ] Keep interaction provider disabled unless a validated licensed provider is integrated and tested.
- [ ] Configure AI only if approved; independently review medical paraphrases and Urdu translations, run the full safety/red-team corpus, and enable the audited server flag after review. The [local AI smoke checks](AI_FEATURES.md) demonstrate specific workflows and do not replace clinical approval.
- [ ] Schedule encrypted backups, immutable storage, retention, success alerts, and periodic isolated restore drills.
- [ ] Run all CI jobs, migrations on fresh and previous schema, dependency/security review, and container startup checks.
- [ ] Supply protected Android release signing, production HTTPS URL, build APK/AAB, and install/test on a real/emulated device.
- [ ] Install full Xcode/CocoaPods/signing if iOS is in release scope.
- [ ] Verify English/Urdu RTL, 200% text, screen-reader semantics, offline cache, reconnect/outbox, cross-user/admin denial, and log redaction.
- [ ] Exercise camera/file/barcode OCR, denied permissions, notification scheduling after restart/timezone/account changes, speech/TTS, biometrics, and export on representative physical devices. Automated tests and an APK build do not prove platform behavior.
- [ ] Review remaining development dependency advisories and plugin toolchain warnings recorded in [release verification](RELEASE_VERIFICATION.md).
- [ ] Record incident contacts, RPO/RTO ownership, on-call alerts, provider/AI kill-switch owners, and release approval.
