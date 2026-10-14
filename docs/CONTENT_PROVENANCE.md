# Content Provenance and Seed Policy

## Current dataset

The included `mediexplain-development-starter` dataset version `2026.08.2` is a small development corpus: 27 terms, 32 morphology elements, 15 abbreviation records, 9 categories, 2 lessons, 4 flashcards, and 4 quiz questions. Its concise definitions and learning text are original development summaries. It is marked `production_approved: false` and `reviewed`, not `approved`.

The seed source is exactly “MediExplain Editorial Development Dataset — Module 2 starter terminology and learning corpus.” No NLM, UMLS, MedlinePlus, or other organization is misrepresented as the author. Selected common mappings were manually checked against public NLM/MedlinePlus educational material, but this does not make the corpus an NLM derivative or a clinically approved dataset.

Reviewed development records are exposed only in development/testing. Production mobile startup does not install the bundled corpus unless it is marked production-approved, the production importer CLI rejects it, and public production APIs/repositories publish only `approved` records.

## Production policy

Production publication requires a legitimately licensed structured provider or clinician/editor-reviewed corpus and must set every record's real provenance, license attribution, review state, and version. UMLS ingestion requires the appropriate UMLS license and honoring restrictions from its component vocabularies. Generic translation output must never be stored as authoritative Urdu content; translations retain method and review metadata.

## Import validation

Both Flutter and backend importers validate schema version, required fields, stable IDs, normalized keys, duplicates, references, and source data before transactional writes. The backend CLI supports dry-run reports. Import failure rolls back reference changes and does not touch saved items, history, or progress.
