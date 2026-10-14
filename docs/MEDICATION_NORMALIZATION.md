# Medication normalization and resolution

Names are never primary keys. `MedicationIdentity` uses UUIDs with brand names, generic name, ordered constituents and independent numerator/denominator strengths, form, country, identifiers (RxCUI/DRAP/barcode), provider mappings, evidence, and a verification state.

The pipeline begins only from a user-confirmed value for prescription input. It normalizes Unicode/spacing for search without overwriting original OCR, corrected text, or prescription snapshots. Country registry and RxNorm candidates are gathered behind interfaces, ranked using exact name/brand/generic, ingredients, strength, form, country, and identifiers, and deduplicated by provider ID. Evidence is retained per signal. Weak results never auto-select; close candidates return ambiguity/user-selection states.

Resolution states are explicit: unresolved, searching, candidates found, ambiguous, selection required, match confirmed, external identity verified, local registry match, no trusted match, and provider unavailable. Imported combination products preserve each ingredient strength; 500 mg + 125 mg is not collapsed to a 625 mg ingredient.
