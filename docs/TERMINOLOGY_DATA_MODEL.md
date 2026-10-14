# Terminology Data Model

## Core record

`MedicalTerm` has a stable ID, canonical/normalized text, pronunciation and optional phonetic form, category/subcategory, source language, review state, record version, deprecation/replacement fields, timestamps, examples, explicit relations, aliases, and curated morphology.

Definitions are child records keyed by term and language with simple, standard, and technical levels. This avoids three unrelated term pages while allowing a translated explanation to retain source language, translation method, review state, reviewer, review time, and content version on the server model.

Aliases are normalized child records with one of `synonym`, `alternative`, `lay`, or `abbreviation`. Abbreviation details also have dedicated records because context, specialty, ambiguity, alternative meanings, and safety warnings cannot be represented safely by a string alone.

## Morphology

`MorphologyElement` represents a reusable prefix, root, or suffix with display and normalized values, meaning, explanation, examples, origin, category, language, source, pronunciation, related elements, and review status. `TermMorphology` joins a reviewed term to elements with exact surface text and offsets. Morphology is stored data, not widget constants.

## Relationships and lifecycle

Term relationships are explicit directed records. Stable IDs preserve saved/history references across content updates. Deprecated records remain addressable internally, may name a replacement, and are excluded from normal search/detail responses.

## Local and server representation

Drift stores the subset needed offline. SQLAlchemy adds translation-review and user-ownership fields needed on the server. Mapping occurs at repository/API boundaries instead of exposing database rows to UI state.
