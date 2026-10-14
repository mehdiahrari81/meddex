# Medical RAG

`MedicalRagService` authenticates context, rejects treatment/injection intent, reloads the selected stable identity and current approved/source-retrieved facts, and prefers exact structured sections. Token-overlap retrieval is a bounded semantic fallback; no personal-history embeddings or model-memory retrieval are used.

The default provider is disabled. Configurable server-only adapters support OpenAI-compatible endpoints and Ollama/local FYP service. Mobile/admin bundles contain no model keys. The same retrieval and validation apply to every adapter.

The response is structured: answer/type, grounding state, application-built source references, safety class, limitations, follow-ups, referenced prescription/medication IDs, language, and whether a model was used. Numeric tokens must exist in trusted context. Generated URLs and unsafe/injection language fail validation. Conflicting jurisdictions/content return source conflict rather than selecting a “winner.” Previous assistant output is never evidence.

Conversation bodies are encrypted at rest, retained for a configurable 30 days by default, and omitted from ordinary analytics/admin review. Patient and student modes vary depth, not facts. English/Urdu explanations retain canonical medicine names and source-language metadata.
