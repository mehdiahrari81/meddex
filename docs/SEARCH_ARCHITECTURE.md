# Search Architecture

## Resolution pipeline

`ResolveMedicalTerm(text)` normalizes Unicode/case/punctuation/whitespace, checks exact canonical text, synonyms, reviewed lay mappings, abbreviations, starts-with/token partials, and bounded Levenshtein candidates. It returns structured resolution metadata: `exact`, `synonym`, `layEquivalent`, `abbreviation`, `partial`, `fuzzy`, `ambiguous`, or `noMatch`.

Ranking bases are deliberately separated: canonical exact 1000, synonym 900, lay 850, abbreviation 800, partial 700/620, and fuzzy 500 plus similarity. Exact and prefix bonuses cannot let fuzzy matching outrank a valid exact result. A typo suggestion is marked and shown; the user's query is never silently changed.

## Candidate retrieval and performance

SQLite and PostgreSQL-compatible queries use indexed normalized terms/aliases, language, category, review status, and first-character narrowing. They fetch a bounded candidate set rather than loading the corpus for each query. Flutter debounces at 180 ms, cancels obsolete generations, and never waits for remote enrichment before showing local data. Public APIs use validated pagination with a maximum page size of 100.

For much larger production imports, PostgreSQL trigram or full-text indexes can replace bounded edit-distance candidate scoring behind the same repository/service contract; Elasticsearch is not justified yet.

## Ambiguity and privacy

If a matching abbreviation has multiple records or an ambiguity flag, resolution becomes `ambiguous` and only abbreviation choices are returned. No context-free winner is selected. Search history records local query/selection/timestamp and is never synchronized. There is no raw-query analytics integration.
