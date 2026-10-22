# Confirm the list, then explain medicines

Delivered 21 October 2026; updated to a separate explanation page on the same date.

## Patient flow

1. Scan a prescription and check the extracted fields.
2. Use **Check** to correct anything wrong. Tap **Confirm** on each medicine; this only saves review and shows a tick.
3. Once every retained medicine is confirmed, tap **Explain medicines** at the bottom of the review page.
4. A separate **Medicine explanations** page opens. The app sends the whole confirmed list in one POST to `/api/v1/prescription-ocr/medicine-overviews`. The backend prepares the reference information and sends one structured AI request containing the complete list. The returned entries appear under their own medicine-name headings. No per-medicine explanation requests are issued by this page. A missing reference or rejected answer does not hide the other entries.
5. The explanation page reloads the saved prescription and validates every retained medicine before requesting summaries. If details are edited or unconfirmed, it requires review again. Back returns to the review page with confirmation ticks preserved. The batch response stays in the page’s provider state; refreshing sends the entire list again. The existing single-medicine cache remains available to saved-medication screens.

No explanation request starts merely because an individual Confirm button is pressed. The existing Add to My Medications flow remains available.

## Why some explanations were missing

The identity step requires a verified reference before asking an AI to explain a medicine. Live diagnosis resolved Cimetidine, Dorzolamidum, Levolin and Calpol, but found reference gaps for Meftal-P and Delcon. A spelling such as “Oxprelol” could not be verified. This is distinct from a cloud generation failure.

Changes:

- Added attributed brand-to-ingredient records for CALPOL, LEVOLIN, MEFTAL-P and DELCON. Exact names are required; suffix variants such as DELCON PLUS/LS and MEFTAL-SPAS are not substituted.
- Curated ingredient verification now supports RxNorm IN, PIN and MIN concepts. This supports precise ingredients and complete combinations while still rejecting product concepts and name mismatches.
- Negative name matches expire after two minutes instead of seven days. The lookup adapter version was advanced so previously cached negative results are refreshed. Successful reference results retain their seven-day cache.
- An unavailable refresh of an old negative match produces a service/retry failure instead of claiming the medicine is unknown.
- A genuinely missing reference now names the affected medicine in its correction message. No spelling, ingredient, strength or dose is guessed.

## Reference provenance

| Exact brand | Ingredient reference | Public identity source |
| --- | --- | --- |
| CALPOL | acetaminophen, also called paracetamol | [CALPOL / Kenvue product information](https://www.calpol.co.uk/) |
| LEVOLIN | levalbuterol, also called levosalbutamol | [Cipla LEVOLIN product information](https://www.ciplamed.com/product-index/levolin-tabletssyrup) |
| MEFTAL-P | mefenamic acid | [Blue Cross Laboratories product information](https://bluecrosslabs.com/wp-content/uploads/2023/02/MEFTAL-P-DT-PI.pdf) |
| DELCON | chlorpheniramine / phenylephrine | [Government of India NPPA formulation reference](https://www.nppa.gov.in/storage/uploads/tender/5943fb12f0f50a8d9a76d1b286b9aa97.pdf) |

These mappings provide general ingredient information. They do not establish product, dose, jurisdictional approval or formulation equivalence. Patient explanations still use the retrieved MedlinePlus/DailyMed sources, shown in the app.

## Verification

- 232 backend tests passed; Ruff and mypy checked all 75 API source files. Batch tests also cover short source-key expansion and selecting the latest source version.
- 264 mobile tests passed; three opt-in live tests skipped in the normal suite. Flutter analysis was clean.
- Widget checks cover the bottom button, no inline explanation sections, navigation to the named explanation list, no request after individual confirmation, disabled Explain before the full list is confirmed, starting every confirmed medicine together, back navigation, unconfirmed-route guarding, failed-load retry, and review/explanation layouts at 200% text size.
- Tests cover PIN/MIN references, all combination components, rejecting other brand variants, negative-cache expiry and retry, and unavailable-reference handling.
- Live HTTP checks returned sourced explanations for Cimetidine, Dorzolamidum, LEVOLIN, CALPOL, MEFTAL-P, DELCON, Betaloc and Lipitor. Eight of eight verified names succeeded. The unverified “Oxprelol” returned its own correction message with no invented explanation. The temporary engineering account was deleted.
- Built, signed, installed and launched the updated release on the connected iPhone 12. Backend readiness passed via the Mac’s Bonjour address. Existing app data was preserved.
- Existing Gemini → Groq → Ollama text fallback remains configured; this change does not load a larger local model.

A correct result still depends on a readable name and a reliable reference. Confirmation by a patient is not independent evidence that OCR identified the medicine correctly.


## Single-request batch delivery

Updated on 21 October 2026 to replace the earlier per-medicine request implementation.

- Input contains 1–40 unique item IDs, reviewed names, optional strengths/forms, an explicit confirmation flag and language. Unconfirmed inputs and duplicate IDs are rejected.
- Exact input IDs and names determine the response order and headings. Model-generated drug names cannot replace them.
- The entire list, including entries with no verified reference, is included in the structured AI prompt. Each supported answer is checked against that medicine’s own source IDs and grounding rules.
- Missing, duplicate, malformed or cross-wired model entries fall back to that medicine’s official source excerpt. Other valid summaries remain visible. Unverified identities remain explicit correction entries; a patient confirmation is not independent proof of medicine identity.
- Gemini is primary; quota/availability failures resend the whole batch to Groq. If both are unavailable, a batch that fits the existing 8K context can use local `qwen3:1.7b`. Larger batches retain source excerpts instead of increasing local memory use.
- `MEDIEXPLAIN_GROQ_BATCH_MAX_OUTPUT_TOKENS` defaults to 8192, with the actual requested budget scaled to list size. The existing smaller output caps for single answers and vision remain in place.
- Transport tests assert one app request containing the full list, stable ordering by ID, no missing/duplicate/renamed results, account isolation and full-list retries. Widget tests forbid the explanation page from using the single-medicine provider.
- The final live HTTP batch containing nine entries completed in 5.85 seconds: eight real verified names received grounded Gemini summaries, and “Oxprelol” remained a correction entry. All nine entries were returned. The temporary engineering account was removed.
- Older duplicate reference versions are excluded from each generation prompt, while the full reference history stays in the database. Short per-batch source keys reduce copying errors; the server expands them to actual reference IDs and checks ownership before citing them.
- A final live Gemini-quota simulation forwarded all nine entries to Groq in one call: all eight verified medicines received grounded AI summaries in 3.21 seconds. Both providers explained DELCON as a complete combination after the source-selection refinement. The temporary account was removed.
- The signed release was installed and launched on the iPhone 12. Backend readiness passed via its Bonjour LAN address. Logs: `/tmp/meddex-real-batch-live-final.log`, `/tmp/meddex-real-groq-batch-live-final.log`, `/tmp/meddex-real-batch-iphone-install.log`.

Cloud quotas, missing reference coverage and incorrectly recognized names remain real limits. The batch endpoint never invents an explanation to conceal one of these conditions.
