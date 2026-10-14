# AI safety

Disallowed intents include diagnosis, prescribing, starting/stopping/replacing medicine, dose changes, invented interactions, doctor impersonation, ignoring sources, or fabricated citations. No retrieval returns insufficient information. Provider timeout/unavailability returns a safe state, never an ungrounded fallback.

Retrieved source/OCR/note text is quoted untrusted data and cannot modify the system policy. Only application metadata creates citations. Numeric grounding prevents new doses, strengths, frequencies, durations, intervals, and percentages. Medication identity retrieval bounds names to the selected trusted entity; the model cannot supply a new medication identity.

The deterministic evaluation covers grounded warning/source output and eleven red-team prompts: prescription/dose manipulation, stopping, diagnosis, interaction fabrication, source bypass, citation fabrication, doctor impersonation, and source injection. All are expected to return `unsafe_to_answer` with no model use.

Emergency control: disable `ai_assistant` server flag; if provider compromise is suspected, rotate its secret and leave the flag disabled until the source/cache/answer review is complete.
