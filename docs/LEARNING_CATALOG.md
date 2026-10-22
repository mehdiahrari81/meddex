# Learning catalog expansion

The bundled starter corpus is preserved byte for byte, including its four quiz
questions and options. `apps/mobile/assets/terminology/learning_expansion_v1.json`
adds 28 lessons (three sections each) and 56 flashcards, bringing the built-in
catalog to 30 lessons and 60 flashcards. Topics cover medicine labels, brands and
generics, safe medicine use, common tests, body systems, and appointment questions.

Every added lesson and its two cards link to a specific public MedlinePlus or FDA
reference in `sources`. Text is an original educational summary. This is the
local development catalog, not an individually clinically reviewed production
release; existing publication approval requirements remain enforced.

## Installation and preservation

Mobile database startup installs the expansion once, identified by its own
`dataset_name` and version. Its additive import preserves existing lesson/card
IDs, administrator edits, categories, source metadata, and all user progress,
review schedules, bookmarks, and quiz attempts. It works offline after installation.
A subsequent administrator reference release continues to use the normal content
refresh workflow.

Both Docker startup commands install the same expansion using:

```sh
python -m app.cli import-reference --if-empty --additive \
  --path /opt/mediexplain/reference/learning_expansion_v1.json
```

`--if-empty` checks the named dataset, rather than treating any existing dataset
as proof that every expansion has already been installed. Repeated startup is
idempotent. No quiz records are included in the expansion.

## Progress and daily terms

Progress shows completed/available lessons and reviewed/available flashcards.
The denominator follows published content, not a hardcoded 30. Database changes
refresh the dashboard automatically. New flashcards count as due before their
first review; scheduled cards stop being due until the next review date. Reading
a completed lesson again does not erase its completion.

Today's Term selects from all available terminology, with stable ID ordering and
one date-based selection for each local calendar day. It advances at midnight,
refreshes after app resume, and cycles through the available terms. Calendar-day
arithmetic is independent of daylight-saving hour changes. With the current
starter terminology there are 34 terms before the cycle repeats.

## Verification

Tests cover additive installation, duplicate prevention, preserved quizzes and
administrator edits, existing and new lesson completion, automatic dashboard
updates, first-review due counts and scheduling, and midnight/resume daily-term
refresh. Full mobile and API suites are also run for delivery.
