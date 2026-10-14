# Medication providers

Implementation documentation was verified against official provider material on August 13, 2026.

## Roles and adapters

- RxNorm `REST-current`, `GET https://rxnav.nlm.nih.gov/REST/Prescribe/drugs.json`: identity normalization, RxCUI, brand/generic/ingredient, form and strength candidates. It is U.S.-centric; unmatched Pakistani products remain unmatched. NLM/RxNorm attribution and source licensing must be retained in deployments.
- MedlinePlus Connect current web service, `GET https://connect.medlineplus.gov/service`: code-first patient-information links. It is not a product registry. Returned title/link attribution remains intact. The adapter uses 24-hour caching, within the documented 12–24-hour guidance; deployments must respect the published 100 requests/minute/IP ceiling.
- DailyMed API v2, `https://dailymed.nlm.nih.gov/dailymed/services/v2`: U.S. SPL lookup and bounded parsing of indications, dosage/administration, contraindications, warnings, precautions, adverse reactions, and storage. Sections retain set ID, label version, jurisdiction, retrieval time, and citation URL.
- DRAP: `DrapDatasetProvider` queries only records from reviewed admin import jobs. No stable documented DRAP product API was found; business logic performs no web scraping. Each product retains registration ID, source name/version, country, ingredients, and optional barcode exactly as imported.
- Interactions: interface exists, runtime state is `not_configured`, feature flag defaults off, and no model-generated interaction result is allowed.

Provider calls use finite HTTP timeouts, no redirects, bounded behavior, a circuit-open threshold, source-specific cache keys/TTL/content hashes, stale preservation, and independently recorded health events. Server flags can disable each external integration or barcode resolution without a mobile release.
