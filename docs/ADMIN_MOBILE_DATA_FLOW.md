# Admin → database → mobile content flow

Updated 22 October 2026. This describes the current `meddex` installation; older dashboard reports describe earlier installations.

## What is connected

The admin website at **http://localhost:3000** sends authenticated requests to FastAPI. FastAPI saves editorial revisions in PostgreSQL. Publishing an individual record updates the corresponding reference table and compiles a new mobile dataset in the same transaction. The Flutter app downloads that dataset and imports it into its offline SQLite database.

```text
Admin form → draft → submit for review → approve → publish
    → PostgreSQL reference tables + versioned mobile release
    → GET /api/v1/content/dataset
    → Flutter validates and imports → learning/search screens refresh
```

Drafts and unapproved edits are not sent to patients. A previous published revision remains available while an update is being prepared. Publication validation checks sources, IDs, and relationships. Revision history and audit events remain available.

## How to demonstrate it

1. Run `python3 scripts/presentation.py` from the project folder and keep that Terminal open. It starts the existing database, API, mail service, and admin container, where present.
2. Open **http://localhost:3000**. Sign in with your existing `mmeekheart@gmail.com` admin account and your private password.
3. Open **Lessons**, **Flashcards**, or **Terminology**. Your existing catalogue is now listed; it is no longer a separate empty editorial list.
4. Open an existing record and create a revision, or choose **Add lesson**, **Add flashcard**, or the corresponding add button. Fill in the labelled form and select its reviewed reference source. Record IDs are generated automatically and preserved during edits.
5. Save the draft with a change reason. Submit it for review, approve it, and publish it. For each action, tick **I confirm this action for this record**, then press the action button. The server still checks the exact record, permissions, lifecycle, and review rules.
6. Return to MediExplain on the iPhone. The updated build checks for reference updates when it starts, returns to the foreground, or regains connectivity. Leave the Mac API running and both devices connected over the configured network.
7. Open the relevant mobile screen. Published lessons contribute to the lesson total; completed lessons, saved terms, and personal medication data are retained.

Updates are fetched on these refresh events, rather than pushed continuously while the app remains in the foreground. If offline, the app keeps its last valid local reference dataset and retries on a later refresh event.

## Adding content without JSON

- **Lessons:** title, description, estimated minutes, objectives, and repeatable sections with **Add section** / **Remove section** buttons.
- **Flashcards:** front, back, optional related term, category, difficulty, and reference source.
- **Medical terms and translations:** term, simple definition, language, examples, category, and source. Other reading levels and alternative names are optional. Blank reading levels reuse the exact simple definition you entered.
- **Word parts:** prefix/root/suffix selector, word part, meaning, explanation, examples, topic, language, and source.
- **Abbreviations:** abbreviation, full meaning, related medical term, context, topic, and optional ambiguity/clarification fields. Attribution comes from the related term.
- **Quizzes:** question, explanation, answer choices, and a radio button for the correct answer. Add/remove answers without editing IDs or arrays.
- **Reference releases:** upload a prepared reference file and enter its source/publisher. This is for bulk content-team imports; individual additions use the ordinary forms above. Invalid files display an error and can be replaced before saving.

Saved records show readable content previews. Raw stored data is available only inside collapsed **Technical record details** for troubleshooting. Routine additions do not require writing JSON or entering record IDs.

## Single-admin exhibition setting

You explicitly requested a local development exception so your one admin account can approve its own revision. The backend enables it only when both conditions hold:

```dotenv
MEDIEXPLAIN_ENVIRONMENT=development
MEDIEXPLAIN_ADMIN_ALLOW_LOCAL_SELF_REVIEW=true
```

The actual environment setting already exists; do not replace unrelated `.env` values. Every self-approval records `content.local_self_review`, the real author/reviewer identity, and the reason. Such a release is not marked production-approved. Production rejects this setting and continues requiring an independent reviewer. No second administrator or fictional review is created.

## Existing content registered

The registration command indexed the existing legitimate reference content without replacing it or inventing new clinical records:

| Module | Records |
| --- | ---: |
| Terms | 34 |
| Word parts | 32 |
| Abbreviations | 23 |
| Lessons | 30 |
| Flashcards | 60 |
| Quiz questions | 4 |
| **Individual editorial records** | **183** |

There is also one automatically managed mobile-release record. The dataset retains 29 reference sources and their attribution. Registration is a migration of existing content into administration, not a claim that it received a new clinical review.

Operator command, if needed on another installation with an existing authorized administrator:

```sh
docker exec meddex-api-1 python -m app.cli register-reference-content \
  --actor-email mmeekheart@gmail.com
```

Running it again registered zero additional records on this installation. It does not delete patient data or replace the PostgreSQL volume.

## Withdrawal and offline behaviour

- Deprecating a published record compiles a new release. Terms, word parts, and lessons become inactive; flashcards and quiz questions are hidden using inactive reference-source status. Explicitly withdrawn abbreviations are removed from the offline reference cache.
- Updated lessons replace obsolete sections; updated quiz questions replace obsolete options. User progress and bookmarks are retained.
- Patients' accounts, prescription images, medicines, dose history, and transactions are not part of the public reference dataset.
- Bulk dataset publication remains an advanced import workflow. For routine editing of the registered catalogue, use individual record revisions; bulk imports do not rewrite the existing individual editorial histories.

## Main implementation files

| File | Purpose |
| --- | --- |
| `services/api/app/services/reference_publication.py` | Register existing reference records, validate individual publications, update canonical tables, compile releases, and handle withdrawal. |
| `services/api/app/services/governance.py` | Draft/review/publish lifecycle, permissions context, independent-review rule, audited local exception. |
| `services/api/app/api/v1/routers/admin.py` | Authenticated editorial list, source/category choices, and workflow API. |
| `services/api/app/api/v1/routers/content.py` | Public reference dataset and authoritative version. |
| `apps/admin/app/(admin)/content/[type]/new/editor.tsx` | Simple forms, generated IDs, repeatable sections/answers, source selectors, and bulk file upload. |
| `apps/admin/components/content-preview.tsx` | Readable saved-content previews. |
| `apps/admin/components/content-workflow-form.tsx` | Explicit checkbox confirmation for review/publication actions. |
| `apps/mobile/lib/app/app.dart` | Refresh references when the app resumes, starts, or reconnects. |
| `apps/mobile/lib/features/terminology/data/terminology_seed_importer.dart` | Validate and atomically update the offline reference tables. |

## Verification

- 275 backend tests passed, covering permissions, review rules, publication, withdrawals, existing-record registration, and existing API features. A new regression check enforces foreign keys when publishing a brand-new quiz; its parent question is now flushed before inserting answer rows.
- 17 admin browser workflows passed against a disposable database, including adding, editing, independently reviewing, and publishing terms, translations, word parts, abbreviations, flashcards, quiz questions, and lessons using forms. Coverage also includes invalid-file recovery and small-screen layout.
- 34 targeted Flutter tests passed, including importing that exact browser-published dataset, preserving lesson progress and bookmarks, and applying withdrawals/revisions.
- Backend lint and typing, admin lint and TypeScript, admin production build, Flutter analysis, and 12 startup/installer regression tests passed.
- The deployed PostgreSQL catalogue contains the 183 registered entries. Its public dataset and version endpoints agree, and the admin login page responds successfully.
- The exact deployed dataset also passed a separate Flutter import and idempotency check against the real offline table schema.
- The signed iOS Release build was installed and launched on the connected iPhone 12. It opens from the home screen without a debugger. Existing app storage was retained.

The browser publication test uses an isolated database; its verification lesson was not inserted into your real clinical reference catalogue.
