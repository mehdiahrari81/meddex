# Offline Terminology and Synchronization

## Bundled canonical copy

Startup imports a validated bundled JSON corpus into indexed Drift tables. Search, detail, morphology, categories, related terms, saved content, lessons, flashcards, quizzes, and progress require no connection. A `content_versions` row records the stable dataset name/version and install/check times.

The included development corpus is imported only by development/testing builds. Production startup validates it without installing it unless `production_approved` is true, preventing reviewed demo records from crossing the publication boundary.

## Reference update flow

A `TerminologyContentProvider` supplies a complete validated dataset to `TerminologyContentUpdateService`. The importer validates before an atomic transaction, upserts stable IDs, refreshes child aliases/morphology/relations, and updates the version last. Failures return a safe error while preserving the installed canonical copy and every user-owned record. Deprecated terms are retained with optional replacements so bookmarks do not become dangling text references.

Incremental provider payloads can be added later behind the same interface; content version synchronization is deliberately separate from the user mutation outbox.

## User data sync

Saved items, lesson progress, quiz attempts, flashcard reviews, and reports persist locally first and enqueue Module 1 operations with entity IDs, idempotency keys, retry state, backoff, and tombstones where appropriate. A disabled transport leaves them safely pending for guests/offline use; an authenticated HTTP transport can replay them to the `/me` endpoints. Search history remains device-local.

## Migration

Drift schema v2 adds Module 2 tables through `onUpgrade` and runs `PRAGMA integrity_check` after upgrades. Tests construct a genuine v1 SQLite schema, retain Module 1 metadata, open it through v2, and verify Module 2 tables. Alembic revision `0002_module_2` upgrades/downgrades the server from Module 1 without dropping identity data.
