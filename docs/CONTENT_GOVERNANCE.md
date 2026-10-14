# Content governance

Governed content uses stable IDs and immutable numbered revisions with author, reason, source metadata, review state, reviewer/review time, and publication time. Lifecycle is draft → in review → approved → published → deprecated → archived. Editors can draft/submit; reviewers approve; publishers publish. Authors cannot approve their own current revision.

Terminology, morphology, abbreviations, lessons, quizzes, and translations share this versioned boundary. Their JSON schemas retain synonyms, ambiguity/alternative meanings, safety notes, language/method/review metadata, learning structure, and sources as applicable. AI translation is a draft until reviewed.

Imports accept bounded JSON (the API model can also be extended with CSV decoding at the adapter boundary), validate required values/duplicates/encoding semantics, store a content hash and staged payload, report added/updated/unchanged/deprecated/rejected/warnings, and require a validated job plus its typed ID to apply. The implemented apply adapter is DRAP product data; unsupported datasets cannot be applied accidentally.

Reports, resolution exceptions, provider health, sources, roles, sessions, flags, and application/content versions are real database views. Annotations do not overwrite registry evidence. Sensitive changes add append-oriented audit events with actor, permission context, request ID, target, safe metadata, and version references.
