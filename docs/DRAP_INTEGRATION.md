# Pakistan DRAP Integration Architecture

## Overview
MediExplain integrates with the Drug Regulatory Authority of Pakistan (DRAP) to provide accurate identification of locally registered medicines. Because DRAP does not provide an official machine-readable API, MediExplain uses a **Controlled Snapshot & Administrative Import** pipeline to securely and robustly load registered drugs.

## Pipeline Flow

1. **Acquisition (Manual/Controlled)**
   - Authorized personnel curate a CSV/XLSX snapshot from the official DRAP e-services index.
   - Required Columns: Registration Number, Brand Name.
   - Recommended Columns: Generic Name, Composition, Dosage Form, Manufacturer.

2. **Admin API Upload (`POST /api/v1/admin/imports/drap/upload`)**
   - The CSV file is securely uploaded via the Admin panel.
   - The FastApi endpoint reads the file and delegates to `DrapParser`.

3. **Validation & Normalization (`app.services.drap_parser.DrapParser`)**
   - The CSV schema is validated.
   - The `Composition Parser` is invoked. It extracts multi-active ingredient strings (e.g. `Amoxicillin 500mg + Clavulanic Acid 125mg`) into structured ingredient lists with normalized values and units.
   - Cryptographic fingerprints (SHA-256) are generated for deduplication.

4. **Staging & Dry-Run (`GovernanceService.dry_run_import`)**
   - The normalized payload is saved to the `content_import_jobs` table as a `dry_run=True` job.
   - Admin receives a JSON diff report containing `added`, `updated`, `warnings`, and `rejected` counts.

5. **Approval & Atomic Merge (`GovernanceService.apply_import`)**
   - Admin verifies the Dry-Run report.
   - Submits `POST /api/v1/admin/imports/{id}/apply`.
   - The `_upsert_drap` function writes to `medication_identities`, `medication_ingredients`, `medication_identifiers`, and `medication_provider_mappings` in a single PostgreSQL transaction.

6. **Search & Indexation (`DrapDatasetProvider`)**
   - Imported products are now searchable via the `DrapDatasetProvider` which uses PostgreSQL `pg_trgm` (trigram similarity) and `ilike` indexing on `normalized_name` to handle misspellings and fuzzy matching.

7. **Cross-Mapping (`RxNormMapper`)**
   - A background job (`map_drap_to_rxnorm`) iterates over newly imported DRAP drugs.
   - It queries the NIH RxNorm API using the generic ingredient names.
   - If a global RxCUI concept is found, a new `MedicationProviderMapping` is appended to the DRAP record, enabling the RAG AI to pull MedlinePlus/DailyMed data for the Pakistani drug.

## Idempotency
Imports are strictly idempotent. Re-uploading the exact same DRAP dataset will generate identical fingerprints and skip redundant database writes, returning `updated: 0, added: 0, unchanged: N`.
