export const contentTypes = new Set(["terminology", "morphology", "abbreviation", "lesson", "flashcard", "quiz", "translation", "dataset"]);

export type ContentRecord = {
  stable_id: string;
  content_type: string;
  lifecycle_state: string;
  current_revision: number;
  published_revision: number | null;
};

export type ContentRevision = {
  revision: number;
  content: Record<string, unknown>;
  source_metadata: Record<string, unknown>;
  author_id: string;
  change_reason: string;
  review_state: string;
  reviewer_id: string | null;
  created_at: string;
  reviewed_at: string | null;
  published_at: string | null;
};


export type ReferenceOptions = {
  categories: { id: string; name: string }[];
  sources: { id: string; title: string; reference: string | null; review_status: string }[];
  terms: { id: string; name: string }[];
};

export function referenceTemplate(type: string): Record<string, unknown> {
  const shared = { id: "", source_id: "", category_id: "", language: "en", review_status: "reviewed", version: 1 };
  switch (type) {
    case "terminology": case "translation": return { ...shared, term: "", normalized: "", definitions: { simple: "", standard: "", technical: "" }, synonyms: [], alternative_spellings: [], lay_terms: [], abbreviations: [], related_term_ids: [], morphology: [], examples: [] };
    case "lesson": return { ...shared, title: "", description: "", difficulty: "beginner", estimated_minutes: 5, objectives: [], review_question_ids: [], sections: [] };
    case "flashcard": return { id: "", source_id: "", category_id: "", type: "termToMeaning", front: "", back: "", difficulty: "beginner", linked_content_id: null };
    case "morphology": return { id: "", source_id: "", type: "prefix", value: "", meaning: "", explanation: "", examples: [], category: "", language: "en", review_status: "reviewed", origin: null };
    case "abbreviation": return { id: "", term_id: "", abbreviation: "", expansion: "", context: "", category: "", ambiguous: false, alternative_meanings: [] };
    case "quiz": return { id: "", source_id: "", category_id: "", type: "chooseMeaning", prompt: "", explanation: "", difficulty: "beginner", linked_term_id: null, options: [{ id: "", text: "", correct: true }, { id: "", text: "", correct: false }] };
    default: return { title: "" };
  }
}
