# Module 2: Terminology and Learning

Module 2 provides local-first terminology search, history, detail explanations, patient/student explanation behavior, morphology, pronunciation through the Module 1 TTS abstraction, abbreviations, categories, explicit related terms, unified saves, a deterministic daily term, lessons, flashcards, quizzes, spaced repetition, streaks, progress, and content reports.

## Screen inventory

The Flutter application contains search/results states, term detail, word decoder, abbreviation explorer, three morphology libraries, category browser, saved terminology, learning home, lesson list/detail, flashcard session/summary, quiz setup/session/results/mistake review, progress, term of the day, and content report. Scanner routes remain honest Module 3 placeholders.

One responsive term-detail presentation selects definition depth from the existing explanation-level and patient/student settings. Patient mode prioritizes the simple explanation and common-language terms. Student or technical mode exposes technical definitions and morphology without hiding the simple definition.

## Educational behavior

Lessons are section-driven records. Progress stores the last section, percentage, timestamps, completion, and review-needed flag. Quiz scoring and mistake review are deterministic. A streak advances only after a lesson section/progress write, quiz completion, or flashcard review—opening a screen is not activity.

## Safety limits

No diagnosis, treatment recommendation, prescription interpretation, OCR, medicine recognition, or LLM-derived definition is implemented. Abbreviations provide context and warnings; ambiguous values such as MS are returned as multiple choices. The small bundled corpus is development-only and visibly labeled as such.
