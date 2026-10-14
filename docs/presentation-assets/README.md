# Presentation diagrams

These diagrams accompany [the FYP presentation guide](../FYP_PRESENTATION_GUIDE.md).

- `system-architecture`: applications, storage, providers, and optional model.
- `prescription-pipeline`: capture, OCR, review, and confirmation.
- `ai-workflow`: source retrieval, generation, validation, and fallbacks.
- `content-governance`: independent review and reference-release distribution.
- `offline-sync`: personal outbox and separate reference-content updates.
- `data-model`: simplified logical relationships, not a full physical schema.

Use PNG files in slides, SVG files for scalable export, and `.dot` sources for editing. Re-render a diagram with Graphviz, for example:

```sh
dot -Tpng -Gdpi=180 docs/presentation-assets/system-architecture.dot -o docs/presentation-assets/system-architecture.png
```

The diagrams describe the implementation reviewed on 12 October 2026. Dashed edges show alternate paths or conceptual associations as labeled.
