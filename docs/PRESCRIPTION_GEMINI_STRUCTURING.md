# Prescription text → medicine entries → simple explanations

**20 October speed update:** scanning and medicine separation now start with `gemini-3.5-flash-lite`, with `gemini-3.5-flash` for temporary outages and a bounded higher-detail review of uncertain handwriting. Explanations load two at a time with a short account-scoped preview cache. See [scan performance measurements](PRESCRIPTION_SCAN_SPEED_2026-10-20.md). This supersedes earlier model/timeout notes below.

Updated 18 October 2026. This replaces the old scan behavior that treated short page headings and patient details as possible medicine names.

## Workflow

1. Choosing **Use this image** starts Gemini image reading automatically. The local/text-only/image method chooser has been removed at the user's request. Camera, photo import, and document/file imports all enter the same processing screen; retry uses the same Gemini image provider. Existing raw-text review tools remain available for correcting saved scans.
2. Authenticated image reading uses `/api/v1/prescription-ocr/handwriting/gemini` with `X-Cloud-Consent: true`, then sends recognized text to `/api/v1/prescription-ocr/structure` with the required cloud-consent flag. The user has explicitly selected this automatic Gemini workflow; there is no extra per-scan method dialog. Account ownership and result review checks are preserved.
3. Gemini separates medicine names and their literal strength, form, quantity, route, frequency, duration, and extra instructions. Doctor/patient names, headings, dates, vitals, tests, and follow-up advice are excluded. The scan opens the medicine cards directly. Original text remains accessible through “View raw OCR text” and each card's source excerpt.
4. The backend validates page/line evidence and checks that each supplied field occurs literally in those lines. Unsupported optional values are discarded and marked uncertain. Unsupported names or invalid source references reject the response. Missing fields remain absent. No OCR spelling, number, dose, or abbreviation is silently repaired or expanded. Duplicate entries with identical source evidence are collapsed.
5. Every generated field is unconfirmed. Internal confidence remains unknown when no calibrated score exists; this is no longer displayed as an “unknown” value badge. The five main fields always appear. Missing content reads “Not written”, safe form abbreviations such as “Tabs” display as “Tablet”, and truly unclear values get a specific check message. Literal OCR doses such as “tab i” remain unchanged and flagged. Confirmed items cannot be overwritten by a later AI reparse.
6. “What this medicine does” loads a simple explanation directly on the card, before prescription confirmation. The authenticated `/api/v1/prescription-ocr/medicine-overview` endpoint uses an exact product reference where available, then resolves a general active-ingredient reference when strength/form variants would otherwise require product selection. NLM RxNorm exact/normalized name lookup and ingredient relationships support generics, brands and combinations; NIH PubChem whole-name compound lookup extends synonym coverage only when independently linked to a RxNorm medicine. Conflicting ingredients are rejected. It does not fuzzy-correct OCR, select a patient's product or confirm a patient resolution. The existing grounded Gemini/Ollama assistant writes two or three short sentences from official references about what the medicine is and its main use. The paragraph appears automatically, with provenance under **Sources and details**. Source-extract fallbacks are labeled. No prescription item is changed by this preview; its response explicitly says `prescription_confirmed: false`.
7. Each medicine offers **Remove medicine**, **Edit details**, and individual confirmation. **Add to My Medications** opens a final review of the whole list as soon as the medicine names and present fields are readable. The final **Confirm and add to My Medications** action explicitly confirms those fields and saves all retained medicines once; individual confirmation is optional. Unclear values lead to editing first. Missing optional fields stay empty. Reminders remain off until the user configures times. A general explanation alone does not confirm a prescription or enable a schedule.

For an older, unconfirmed scan, open its raw-text review and tap **Separate medicines with Gemini** to replace the previous unconfirmed candidates. Confirmed items are protected; review/delete individual incorrect entries explicitly rather than automatically overwriting them.

The local rule parser remains available when cloud processing is declined. It now requires explicit medicine evidence such as a strength or dosage form and filters common metadata headings; isolated unknown names can be entered manually. Gemini failure/quota errors preserve the OCR draft and offer retry, raw-text review, or manual entry. They do not silently restore the old whole-page-to-medicines behavior. Ollama continues as the **assistant's** fallback; it does not receive prescription-structuring text in this implementation.

## Configuration and persistence

The existing ignored `services/api/.env` supplies `MEDIEXPLAIN_GEMINI_API_KEY` and `MEDIEXPLAIN_GEMINI_MODEL` (currently `gemini-3.5-flash-lite`). No key is embedded in the app. Requests are bounded to 10 uniquely numbered pages, 15,000 characters per page and 30,000 per document, with a 30-second Gemini timeout and at most 40 entries. The generation schema is flattened and kept simple for Gemini; full Pydantic bounds and strict output validation run on the server afterward.

The extraction endpoint has authentication, existing rate limiting, and `Cache-Control: no-store`; it does not store OCR text, images, or model output server-side. Existing account-scoped local persistence stores the review draft and parser/model provenance in existing columns. Page-specific OCR text can be restored after an app restart. Confirmed prescriptions and existing legitimate records are preserved.

## Verification

- 141 API tests passed, including extraction shape, metadata filtering, hallucinated-name rejection, numeric preservation, uncertain spellings, page attribution, duplicates, empty results, consent/authentication, bounded input, safe provider/quota errors, exact reference selection, rejection of ambiguous products, preview authentication, no implicit prescription confirmation, shared-ingredient grounding, separate image-upload consent, metadata removal, image bounds, uncertainty propagation and the attributed Betaloc ingredient reference.
- 153 Flutter tests passed (the additional live API test is opt-in and was also run separately), including complete-text-only transport, separately consented Gemini image transport, authenticated ownership, logout during extraction, unconfirmed field mapping, no invented missing dose, metadata filtering, persisted OCR recovery, retry advancing to confirmation, protection of individually confirmed fields, five readable medicine fields without confidence badges, automatic explanation before confirmation, BD display without changing the written value, actionable network/session/quota errors, and narrow-screen layout at 200% text size. Existing parser, persistence, reminder, sync, accessibility, routing, and session tests remain in the suite.
- Flutter analysis, Ruff, strict mypy, and Xcode project validation passed.
- A live Gemini engineering fixture containing page headers, synthetic doctor/patient labels, date, blood pressure, tests, and two medicines returned only the two medicine entries in approximately 1.7 seconds. This is a synthetic test, not a patient record or a prescription-accuracy benchmark.
- A real authenticated HTTP flow returned two medicines in approximately 2 seconds, successfully resolved the selected genuine medicine identity, retrieved eight attributed official facts, and generated a grounded Gemini explanation with an official citation. The temporary QA account was deleted; no synthetic prescription records were stored.
- The updated signed Release app was installed and launched on the connected iPhone 12, using the existing profile and preserving the app's installed data. It launches without a debugger. The laptop API remained healthy.
- The Android debug APK built successfully; required Flutter/Dart JNI/SQLite libraries were verified for arm64-v8a, armeabi-v7a, and x86_64.
- The Lipitor 10 mg / Tabs case from the reported UI was checked against live RxNorm and MedlinePlus data. The exact reference was `atorvastatin 10 MG Oral Tablet [Lipitor]`; Gemini returned a short explanation with official citations while `prescription_confirmed` remained false. A separate cached ingredient record no longer causes correct brand/generic explanations to be rejected as unrelated drugs.

The latest local phone deployment uses `http://mahdis-MacBook-Air.local:8000/api/v1/`, avoiding stale IP addresses after Wi-Fi/DHCP changes. The reported extraction and explanation failures came from the phone and Mac using different Wi-Fi networks. Both must share a reachable network and the API must be running. After reconnecting, a real iPhone test passed authenticated Gemini extraction and the medicine explanation in 3.93 seconds; all five native device tests passed.

Failure responses now distinguish Gemini quota, unavailable extraction, unverified extraction and unavailable medicine sources using safe codes. The mobile app distinguishes these from connection failure, timeout and expired login, and gives appropriate recovery instructions without exposing upstream details or private OCR text. Server diagnostics record only failure category/status and request ID. A missing local session now yields a sign-in instruction instead of a generic extraction failure.

Additional validation: the mobile Dart transport/decoders passed live registration, session persistence and refresh, Gemini separation, sourced explanation, logout and login against the API. Four additional differently formatted synthetic OCR fixtures passed Gemini extraction. A simulated Gemini 429 triggered a real `qwen3:1.7b` inference through the app's grounded assistant service in 9.41 seconds; generated provider/model, quota fallback reason and citations were asserted. The 8B model was not called. These fixtures are QA only, not clinical records; temporary QA accounts are removed and the fallback transaction is rolled back.

## Handwriting and Betaloc update

The optional authenticated `/prescription-ocr/handwriting/gemini` endpoint requires `X-Cloud-Consent: true` separately from the text-only structuring consent. Images are limited to 6 MB / 16 megapixels, normalized to JPEG with camera/GPS metadata removed, and processed in memory. `MEDIEXPLAIN_GEMINI_HANDWRITING_MODEL` defaults to `gemini-3.8-flash`; text separation and the primary assistant keep their existing model. The standard 3.5 Flash model returned upstream overload errors during the check, while 3.8 Flash was available. No additional local model is installed or loaded. The image reader returns full text, then the existing evidence-validated medicine extraction runs. Unreadable regions and doubtful lines are marked and remain unconfirmed. A real image-to-Gemini-to-structured-medicines fixture passed for Betaloc, 50 mg and BD; the live mobile HTTP test also passed the authenticated image endpoint, text separation and Betaloc explanation. These are engineering fixtures, not a clinical handwriting benchmark. A difficult public IAM word fixture was not read exactly; the selected model flagged the doubtful reading. Handwriting accuracy remains a material limitation.

BD is displayed as **BD — twice a day**, with an explanation that the handwritten letters still need checking. The literal stored value and schedule-confirmation rules remain unchanged. Other supported frequency expansions follow the [NHS abbreviation guide](https://www.nhs.uk/nhs-app/help/understanding-abbreviations/); ambiguous terms such as OD are not automatically expanded.

Recognized frequency abbreviations such as BD/BID use normal text and a neutral review hint rather than red error styling. Their unconfirmed/ambiguous state is retained until explicit user review. Unclear medicine names, doses and unrecognized frequencies retain their existing warnings. Ingredient-reference explanations now state the relationship up front, for example **Betaloc is a brand of metoprolol (the active ingredient)**. The displayed prescription medicine name is preserved. Five targeted review-screen tests pass, including a new regression checking the neutral BID color, retained review requirement and the visible brand/ingredient link; Flutter analysis passes.

The curated [brand reference catalogue](../services/api/app/reference/medicine_brands.json) records Betaloc → metoprolol using [NHS SPS](https://mca.sps.nhs.uk/mca/betaloc-50mg-tablets-astrazeneca-uk-ltd) and Betaloc CR → metoprolol using [Medsafe](https://www.medsafe.govt.nz/profs/datasheet/b/BetalocCRtab.pdf). These are ingredient-information links with source jurisdiction and verification timestamp, not US product verification or release-form equivalence. RxNorm ingredient 6918 is independently checked against its exact properties before use. The general explanation uses the existing cited medical RAG workflow. The brand evidence is cached idempotently against the generic reference; existing patient records and confirmations are preserved. Unknown names now offer correction directly, without substituting a guessed medicine.

## Recognition limits

Text structuring cannot recover medicine names that OCR failed to read. Unclear handwriting needs correction against the image or pharmacist/prescriber clarification. The model can omit or misassociate text despite evidence validation; review is required. General medicine explanations are distinct from confirming what a particular patient was prescribed. Clinical accuracy and every physical camera/device scenario are not established by these engineering tests.


## General medicine explanations

The explanation path no longer asks patients to choose between strengths or forms just to learn what a medicine does. Ingredient references preserve every ingredient in combination medicines and distinguish brand, generic and synonym relationships; they never alter the prescription name or instructions. Unresolvable names offer spelling correction and retry rather than a guessed explanation. Public name-to-ingredient results are cached for seven days using the existing database provider cache, with source URLs and retrieval timestamps. No additional model or dependency is required. Gemini remains primary and `qwen3:1.7b` remains the local assistant fallback.

Identity sources: [NLM RxNorm name search](https://lhncbc.nlm.nih.gov/RxNav/APIs/api-RxNorm.findRxcuiByString.html), [RxNorm ingredient relationships](https://lhncbc.nlm.nih.gov/RxNav/APIs/api-RxNorm.getRelatedByType.html), and [NIH PubChem PUG REST](https://pubchem.ncbi.nlm.nih.gov/docs/pug-rest). Patient explanations use existing attributed MedlinePlus/DailyMed facts. Normalized RxNorm matching is limited to general ingredient information; salt/release/strength equivalence is never inferred for a patient's prescription. Reference coverage and legibility still limit automatic explanations; no claim of recognition for every possible medicine or handwriting is made.


Latest verification for general explanations: **150 API tests and 155 Flutter tests passed**, plus the opt-in live mobile HTTP test. Live source-backed explanations succeeded for metformin, amoxicillin, Augmentin, paracetamol, Panadol, Concor, hydrocortisone, Ventolin and levothyroxine. The mobile live test also passed Lipitor and Betaloc explanations, generic/combination/synonym/international ingredient previews without strength/form selection, consented image-to-Gemini extraction using a synthetic fixture, registration, persistent sessions, refresh, logout and login. Ruff, strict mypy (72 files), Flutter analysis and signed iOS Release compilation passed. The updated app was installed and its process verified on the iPhone 12; the rebuilt API and database passed readiness checks. Temporary QA users were removed; genuine public reference caches were retained. The assistant configuration was checked as Gemini primary with `qwen3:1.7b` fallback; no model changes or new model downloads were needed for this update.


## Scan deletion, reviewed medication list, and cloud recognition update

The scan screen's **Continue reviewing prescription** card includes a delete button. The review, history detail, and final confirmation screens also offer prescription deletion. Individual medicine deletion waits for the database transaction, reloads the latest workflow state and gives visible success/failure feedback; asynchronous draft loads are versioned so a stale result cannot restore a deleted entry. The medicine cards have stable item keys and a direct **Remove medicine** action in addition to the menu. Whole-scan deletion clears private images, OCR results and draft entries, refreshes the resume card and queues the existing sync tombstone. Medicines previously added to **My Medications** remain saved with their reviewed instruction snapshot after deleting the source scan.

Reviewed medicines can be saved without inventing an absent dose/frequency or reminder time. New plans from this list have reminders off; reminder activation still requires confirmed scheduling details. Repeated Add actions are idempotent for each prescription item, and the final button disables itself while saving. The backend accepts these inactive plans, enforces ownership, and retains existing source snapshots after deletion of the original scan. The live mobile transport test now verifies saving every extracted fixture medicine, idempotency, synchronization, source-scan deletion and later medication updates.

For handwriting, **Use this image** now directly starts Gemini image reading, bypassing ML Kit/Apple Vision for recognition and removing the extra method dialog. Saved-scan text review and recovery tools remain available. Photo preprocessing preserves color, uses conservative contrast changes rather than removing pale writing, keeps up to 3200 pixels on the longest side and uses JPEG quality 95. Both the image and prescription-text stages now use `gemini-3.8-flash`; the general assistant stays on its existing primary model and `qwen3:1.7b` fallback. Google's documented [high media resolution](https://ai.google.dev/gemini-api/docs/generate-content/media-resolution) is requested for image reading. Exact uncertain text spans are tagged separately, so a doubtful dose does not automatically hide the explanation for an otherwise clear medicine name. Where the model cannot localize uncertainty, the whole line remains flagged. The model is instructed to inspect every medicine row and its continuation lines; evidence validation still rejects invented names/numbers.

Validation: **154 API tests and 160 Flutter tests passed**, Ruff, strict mypy and Flutter analysis passed, and the live mobile API test passed. A separate synthetic three-medicine image fixture returned Betaloc, Augmentin and paracetamol with all five required written fields and a sourced explanation for each, excluding follow-up advice and blood pressure. BID remained flagged for review. These fixtures are not clinical handwriting accuracy benchmarks. Larger cloud model probes returned quota errors with the configured account; the selected 3.8 Flash model was available and passed the live workflow. No larger local model was installed. Handwriting, ambiguous medicine identity, unavailable reference coverage and cloud quotas remain limitations; no recognition guarantee for every possible prescription is implied.


The final signed Release build was installed and launched on the connected iPhone 12, and its running process was verified. The backend passed `/api/v1/ready` over the configured `.local` hostname. The My Medications list now offers **View medicine explanation**, instead of showing a cached unavailable label before checking the actual source-backed overview. The detail screen loads that overview automatically. Temporary accounts created by the final live checks were deleted along with their synthetic QA records; genuine public reference caches were preserved. The 1.7B Ollama model was installed but unloaded at completion, and no 8B model was loaded by these checks.

## Draft deletion and Wi-Fi correction — 19 October 2026

The reported unchanged resume card was reproduced with multiple unfinished drafts. Deletion removed the selected prescription and its image files, but `latestDraft()` immediately promoted an older scan into a card with identical text. Read-only inspection of the connected phone confirmed deleted records and additional unfinished scans; it did not reveal corrupt foreign keys or malformed image IDs.

The scan screen now identifies the draft by capture date and medicine names. Confirmation stays visible with a disabled button and progress indicator until deletion finishes; an error stays in the dialog with a retry action. Successful deletion replaces the resume card with a persistent receipt and a button opening the remaining unfinished prescriptions. History also has a delete button on each dated card. Starting a new capture restores normal resume behavior. No other draft is automatically deleted.

Offline save-then-delete now retains the minimum reviewed medicine snapshot needed to back up medicines already chosen for My Medications. Outbox prerequisites ensure source verification, medication saving, and source deletion run in that order, including retry/backoff. Images, full raw OCR, and unrelated deleted medicines are not uploaded by that retained snapshot. Local prescription items/pages/OCR are removed immediately. Prescription DELETE is idempotent for never-synced drafts and lost responses and remains owner scoped.

The wider audit also corrected reminder editing to preserve weekdays, interval/anchor, as-needed tracking, and original instructions. The first reminder schedule for an inactive scan-saved medicine uses the device timezone explicitly. Missing dose/frequency prevents reminder creation with a clear message rather than an unhandled error.

Verification: 174 Flutter tests passed (cloud live tests are separately opt-in); 155 API tests passed; Flutter analysis, Ruff and mypy passed. New real-file tests cover multipage deletion, retained unrelated files, missing files, reopening SQLite, repeat deletion, and clean foreign keys. Widget tests cover multiple drafts, cancellation, history deletion, in-progress state/retry, and reminder editing. A separate real-API test passed registration/session refresh/login/logout, offline save-delete-sync, retained My Medications, never-synced deletion, and temporary-account cleanup. Live Gemini extraction was blocked during this check because Google returned HTTP 401 `UNAUTHENTICATED` / invalid API key; this is recorded as an external credential limitation, not a passing AI check.

## Handwriting detail reading (19 October 2026)

The image reader now sends a metadata-free page overview and, for sufficiently
large portrait pages, three overlapping full-width detail views. They are
explicitly identified as views of the same page to avoid treating overlaps as
additional prescriptions. Detail crops preserve color and pale strokes; an
adaptive second read uses grayscale/autocontrast views without thresholding,
erasure, sharpening, or generated image content. Combined JPEG bytes are capped
at 8 MB before base64 encoding, and individual views are capped at 4 MB.

The prompt asks the reader to inspect joined strokes, dots, numbers, continuation
lines, and the writer's repeated letter shapes. It must preserve literal text,
including ordinary non-medicine words, and must not choose a plausible medicine
instead of reading the image. Google's documentation describes
[multiple image parts](https://ai.google.dev/gemini-api/docs/generate-content/image-understanding)
and [high-resolution image input](https://ai.google.dev/gemini-api/docs/generate-content/media-resolution).

Only doubtful lines receive a second cloud read (at most six lines and one extra
request). The response must reference existing zero-based line indexes. It cannot
replace clear lines, clear numbers, or clear instructions. Recovered text remains
uncertain, and both readers' doubts are retained. An unavailable, malformed, or
misaligned second response leaves the first reading intact. Clear pages skip
this extra request. Images and temporary views remain in memory on the API.

The primary remains `gemini-3.8-flash`; no larger local model or new dependency is
installed. During verification Google intermittently returned 503 for both image
reading and text separation. These prescription operations now permit one
bounded alternate-cloud attempt using `gemini-3.5-flash` for temporary 408/5xx
errors. They do not retry quota/authentication errors or blocked, truncated, or
invalid output. The response identifies the model actually used. The medical
assistant's existing Gemini/Ollama policy is unchanged.

Optional server settings in `services/api/.env`:

```dotenv
MEDIEXPLAIN_GEMINI_HANDWRITING_RECHECK=true
MEDIEXPLAIN_GEMINI_HANDWRITING_FALLBACK_MODEL=gemini-3.5-flash
MEDIEXPLAIN_GEMINI_PRESCRIPTION_FALLBACK_MODEL=gemini-3.5-flash
```

Verification: 170 API tests passed, with Ruff and strict mypy clean. Tests cover
crop coverage/overlap, metadata removal, byte limits, line-index validation,
uncertainty propagation, protected written numbers, clear-page request counts,
failed second-read recovery, and bounded availability fallback. Live Gemini
recognized all three names and written fields on a **synthetic cursive engineering
fixture**, and a separate forced-doubt test exercised the actual cloud second
read, recovering Betaloc while preserving its review flag. These are functional
checks, not a clinical handwriting benchmark. No failed real prescription from
the user was available for a before/after accuracy measurement; genuinely
illegible handwriting still requires checking the original or asking the prescriber.

Deployment verification: the running Docker API loads `gemini-vision-v3` and is
healthy on the existing Wi-Fi address. The final authenticated HTTP smoke check
was blocked by Google's current high-demand 503 responses from both configured
models; a single-image control failed with the same upstream error. Earlier direct
live calls recognized the cursive fixture and completed the forced-doubt recheck.
No success claim is made for the final full HTTP check or for real difficult
prescriptions. Both temporary QA accounts were removed, and no prescription or
medication records were created by these checks.
