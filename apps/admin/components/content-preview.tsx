import type { ReferenceOptions } from "@/lib/content";

type Data = Record<string, unknown>;
const labels: Record<string, string> = {
  title: "Title", term: "Medical term", value: "Word part", abbreviation: "Abbreviation",
  expansion: "Full meaning", prompt: "Question", front: "Front", back: "Back",
  description: "Description", meaning: "Meaning", explanation: "Explanation",
  context: "Where it is used", category: "Topic", language: "Language",
  difficulty: "Difficulty", estimated_minutes: "Estimated minutes", pronunciation: "Pronunciation",
  origin: "Word origin", examples: "Examples", objectives: "Learning objectives",
  synonyms: "Other names", alternative_spellings: "Alternative spellings", lay_terms: "Everyday names",
  abbreviations: "Short names", alternative_meanings: "Other possible meanings", safety_warning: "Important clarification",
};

export function ContentPreview({ content, options }: { content: Data; options: ReferenceOptions }) {
  const source = options.sources.find(s => s.id === content.source_id);
  const category = options.categories.find(c => c.id === content.category_id);
  const linked = options.terms.find(t => t.id === (content.term_id || content.linked_term_id || content.linked_content_id));
  const definitions = content.definitions as Data | undefined;
  const sections = Array.isArray(content.sections) ? content.sections as Data[] : [];
  const answers = Array.isArray(content.options) ? content.options as Data[] : [];
  return <div className="content-preview">
    <dl>{Object.entries(labels).map(([key, label]) => {
      const value = content[key];
      if (value === undefined || value === null || value === "" || (Array.isArray(value) && !value.length)) return null;
      return <div key={key}><dt>{label}</dt><dd>{Array.isArray(value) ? <ul>{value.map((v, i) => <li key={i}>{String(v)}</li>)}</ul> : String(value)}</dd></div>;
    })}
    {category ? <div><dt>Category</dt><dd>{category.name}</dd></div> : null}
    {source ? <div><dt>Reference source</dt><dd>{source.title}{source.reference ? <p className="muted">{source.reference}</p> : null}</dd></div> : null}
    {linked ? <div><dt>Related medical term</dt><dd>{linked.name}</dd></div> : null}
    {typeof content.ambiguous === "boolean" ? <div><dt>More than one meaning</dt><dd>{content.ambiguous ? "Yes" : "No"}</dd></div> : null}
    </dl>
    {definitions ? <><h3>Definitions</h3><dl>{["simple", "standard", "technical"].map(key => definitions[key] ? <div key={key}><dt>{key[0].toUpperCase() + key.slice(1)}</dt><dd>{String(definitions[key])}</dd></div> : null)}</dl></> : null}
    {sections.length ? <><h3>Lesson sections</h3>{sections.map((s, i) => <section className="editor-item" key={i}><h4>{String(s.title)}</h4><p className="preserve-lines">{String(s.content)}</p></section>)}</> : null}
    {answers.length ? <><h3>Answer choices</h3><ol>{answers.map((a, i) => <li key={i}>{String(a.text)} {a.correct ? <strong>— Correct answer</strong> : null}</li>)}</ol></> : null}
    {content.schema_version ? <><h3>Reference release</h3><p>Version {String(content.dataset_version)}</p><ul>{["terms", "morphology", "abbreviations", "lessons", "flashcards", "quiz_questions"].map(key => <li key={key}>{key.replaceAll("_", " ")}: {Array.isArray(content[key]) ? content[key].length : 0}</li>)}</ul></> : null}
  </div>;
}
