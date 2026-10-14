# Architecture

## Platform foundation

Module 1 established feature-first Flutter code, Riverpod composition, GoRouter navigation, localized design-system widgets, Drift persistence, secure session storage, a Dio network boundary, authenticated FastAPI services, and an idempotent user-data outbox. Later modules extend those seams instead of introducing parallel foundations.

## Module boundaries

`features/terminology` owns medical records, normalization, search resolution, morphology parsing, local reference-content queries, search history, content updates, and terminology presentation. `features/learning` owns lessons, flashcard schedules, quiz scoring, streaks, progress, and learning screens. `features/saved` owns unified bookmarks while referencing stable terminology IDs.

Widgets consume domain models and application providers. Search, fuzzy matching, parsing, scoring, scheduling, and streak rules are not implemented in widgets. The public `ResolveMedicalTerm` use case accepts ordinary text independent of its source, allowing later OCR or speech providers to call it without depending on a text field.

`features/intelligence` owns API DTO conversion, internal medication identities, resolution evidence, source-aware local snapshots, and grounded-answer rendering. Provider DTOs terminate in the backend adapter layer. `apps/admin` is a separate server-rendered security boundary and never shares mobile tokens.

Medication flow is `user-confirmed value → provider adapters → evidence-ranked candidates → ambiguity/user selection → stable MedicationIdentity → structured MedicalFact/provenance`. Explanation flow is `authenticated context → structured retrieval → bounded semantic fallback → optional server-side model → numeric/name/safety validation → application-built citations`. If retrieval or validation fails, the service returns a typed safe state and does not call on model memory.

## Data flows

Reference content follows `validated dataset -> transactional importer -> versioned canonical local/server tables`. User data follows `local mutation -> local user table -> Module 1 idempotent outbox -> authenticated API`. Reference updates never use the user outbox.

The API exposes public, review-filtered terminology and learning content plus authenticated saved/progress/review/attempt routes. Pydantic schemas are response boundaries; SQLAlchemy entities do not leak internal fields. Search and report endpoints share the existing fixed-window rate limiting infrastructure.

## Safety and privacy

Only `reviewed` or `approved` reference records are returned by normal APIs. Abbreviation ambiguity is explicit. Morphology explains structure but never synthesizes an authoritative medical definition. Search history stays local. Raw search strings are not sent to analytics. Content reports are queued for editorial review and never mutate content automatically.
