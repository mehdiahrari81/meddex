# Learning Engine

## Content

Lessons have objectives, category, difficulty, estimated length, sourced sections, linked terms, review questions, status, and version. Rendering is content-driven. Flashcards support term-to-meaning, meaning-to-term, element-to-meaning, and abbreviation-to-expansion formats. Quiz models support multiple choice, true/false, matching-ready, morphology identification, meaning/term selection, and abbreviation meaning.

The offline client stores correct option IDs because offline scoring is an explicit FYP requirement. API quiz responses omit correctness flags, leaving a safe boundary for later server-authoritative or competitive scoring.

## Progress and recommendations

Lesson progress stores start, resume position, percentage, completion, review flag, and timestamps. Quiz attempts store selected option IDs and correctness. Flashcard schedules store repetition state. Dashboard values are SQL aggregates of actual progress—never placeholder metrics.

Current deterministic recommendations prioritize due cards and unfinished lessons. Category weakness fields are optional until enough category-tagged attempts exist; the UI does not fabricate them. Difficulty filters lessons, cards, and quiz questions without removing basic definitions.

## Quiz scoring

`QuizEngine` uses exact set equality between submitted and correct option IDs. Unanswered questions are incorrect. Results include accuracy and a mistake list containing the question, selected answer, correct option, and reviewed explanation. Users can review weak areas after completion.
