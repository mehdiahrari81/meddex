"use client";

import { useActionState, useRef, useState } from "react";
import { referenceTemplate, type ReferenceOptions } from "@/lib/content";
import { createContent, type EditorState } from "./actions";

type RecordData = Record<string, unknown>;
type Choice = { id: string; name: string };
const difficulties = ["beginner", "intermediate", "advanced"].map(id => ({ id, name: id[0].toUpperCase() + id.slice(1) }));

export function Editor({ type, stableId, content, source, options }: {
  type: string; stableId?: string; content?: RecordData; source?: RecordData; options: ReferenceOptions;
}) {
  const [state, action, pending] = useActionState(createContent, {} as EditorState);
  const [data, setData] = useState<RecordData>(content ?? referenceTemplate(type));
  const [fileError, setFileError] = useState("");
  const [filename, setFilename] = useState("");
  const [releaseId, setReleaseId] = useState(stableId ?? "");
  const [releaseSource, setReleaseSource] = useState(String(source?.provider ?? ""));
  const fileRead = useRef(0);
  const [readingFile, setReadingFile] = useState(false);
  const dataset = type === "dataset";
  const term = type === "terminology" || type === "translation";
  const set = (key: string, value: unknown) => setData(previous => {
    const next = { ...previous, [key]: value };
    if (!dataset && !next.id) next.id = `${type}-${crypto.randomUUID()}`;
    if (type === "quiz" && Array.isArray(next.options)) {
      next.options = (next.options as RecordData[]).map((option, i) => ({ ...option, id: option.id || `${next.id}-answer-${i + 1}` }));
    }
    return next;
  });
  const string = (key: string) => String(data[key] ?? "");
  const lines = (key: string) => Array.isArray(data[key]) ? (data[key] as string[]).join("\n") : "";
  const sections = (Array.isArray(data.sections) ? data.sections : []) as RecordData[];
  const answers = (Array.isArray(data.options) ? data.options : []) as RecordData[];
  const definitions = (data.definitions ?? {}) as RecordData;
  const serialized: RecordData = term ? {
    ...data,
    definitions: { ...definitions, standard: definitions.standard || definitions.simple, technical: definitions.technical || definitions.standard || definitions.simple },
  } : data;
  const cleaned = { ...serialized };
  for (const key of ["objectives", "examples", "synonyms", "alternative_spellings", "lay_terms", "abbreviations", "alternative_meanings"]) {
    if (!dataset && Array.isArray(cleaned[key])) cleaned[key] = (cleaned[key] as string[]).map(value => value.trim()).filter(Boolean);
  }
  const computedId = dataset ? releaseId : stableId ?? (string("id") ? `${type}.${string("id")}` : "");
  const select = (key: string, label: string, entries: Choice[], required = true) => <label>{label}<select aria-label={label} value={string(key)} onChange={e => set(key, e.target.value || (required ? "" : null))} required={required}><option value="">{required ? `Choose ${label.toLowerCase()}` : "None"}</option>{entries.map(v => <option value={v.id} key={v.id}>{v.name}</option>)}</select></label>;
  const text = (key: string, label: string, required = true, multiline = false) => <label>{label}{multiline ? <textarea rows={4} value={string(key)} onChange={e => set(key, e.target.value)} required={required} /> : <input value={string(key)} onChange={e => set(key, e.target.value)} required={required} />}</label>;
  const lineList = (key: string, label: string, required = false) => <label>{label}<textarea rows={3} value={lines(key)} onChange={e => set(key, e.target.value.split("\n"))} required={required} /></label>;
  const replaceSection = (index: number, changes: RecordData) => set("sections", sections.map((s, i) => i === index ? { ...s, ...changes } : s));
  const reference = options.sources.find(s => s.id === data.source_id);

  return <form action={action} className="form-grid" aria-busy={pending || readingFile}>
    {state.error || fileError ? <div className="error" role="alert">{state.error || fileError}</div> : null}
    <input type="hidden" name="contentType" value={type} />
    <input type="hidden" name="stableId" value={computedId} />
    <input type="hidden" name="content" value={JSON.stringify(cleaned)} />
    <input type="hidden" name="sourceMetadata" value={JSON.stringify({ ...source, ...(data.source_id ? { source_id: data.source_id } : {}), ...(dataset ? { provider: releaseSource } : {}), ...(filename ? { uploaded_filename: filename } : {}) })} />
    <p className="editor-intro">Fill in the information below and save your draft. Review and publication happen afterward. Record numbers and formatting are handled automatically.</p>
    <fieldset disabled={pending}>
      <legend className="editor-heading">{dataset ? "Upload a prepared reference release" : "1. Content"}</legend>
      {dataset ? <>
        <p className="muted">For adding a single lesson, medicine term, flashcard, or question, use its page in the sidebar. This upload is for a complete reference dataset prepared by your content team.</p>
        <label>Reference dataset file<input type="file" accept=".json,application/json" required={!content} onChange={async e => {
          const file = e.target.files?.[0];
          const read = ++fileRead.current;
          setFileError(""); setFilename("");
          if (!file) { setReadingFile(false); setData(content ?? {}); return; }
          setReadingFile(true);
          try {
            if (file.size > 3_000_000) throw new Error("Choose a reference file smaller than 3 MB.");
            const document: unknown = JSON.parse(await file.text());
            if (!document || typeof document !== "object" || Array.isArray(document) || (document as RecordData).schema_version !== 1 || !(document as RecordData).dataset_version) throw new Error("This is not a supported reference dataset. Ask your content team for a version 1 reference file.");
            if (read !== fileRead.current) return;
            setData(document as RecordData); setFilename(file.name);
            if (!stableId) setReleaseId(`dataset.${crypto.randomUUID()}`);
          } catch (error) {
            if (read === fileRead.current) { setData({}); setFileError(error instanceof SyntaxError ? "This file could not be read. Choose a valid reference dataset file." : (error as Error).message); }
          } finally { if (read === fileRead.current) setReadingFile(false); }
        }} /></label>
        {readingFile ? <p role="status">Checking file…</p> : null}
        {data.dataset_version ? <p className="success" role="status">{filename || "Current release"} · Version {String(data.dataset_version)} · {Array.isArray(data.terms) ? data.terms.length : 0} terms · {Array.isArray(data.lessons) ? data.lessons.length : 0} lessons</p> : null}
        <label>Source or publisher<input value={releaseSource} onChange={e => setReleaseSource(e.target.value)} required /></label>
      </> : type === "lesson" ? <>
        {text("title", "Title")}
        {text("description", "Description", true, true)}
        <label>Estimated minutes<input type="number" min={1} max={180} value={Number(data.estimated_minutes)} onChange={e => set("estimated_minutes", Number(e.target.value))} required /></label>
        {lineList("objectives", "Learning objectives (one per line)", true)}
        <fieldset><legend>Lesson sections</legend>
          {!sections.length ? <p className="muted">Add at least one section for the lesson.</p> : null}
          {sections.map((section, i) => <div className="editor-item form-grid" key={String(section.id || i)}>
            <label>Section {i + 1} title<input value={String(section.title ?? "")} onChange={e => replaceSection(i, { title: e.target.value })} required /></label>
            <label>Section {i + 1} text<textarea rows={5} value={String(section.content ?? "")} onChange={e => replaceSection(i, { content: e.target.value })} required /></label>
            <button className="button secondary" type="button" onClick={() => set("sections", sections.filter((_, index) => index !== i).map((s, position) => ({ ...s, position })))}>Remove section {i + 1}</button>
          </div>)}
          <button className="button secondary" type="button" onClick={() => set("sections", [...sections, { id: `section-${crypto.randomUUID()}`, title: "", content: "", type: "text", position: sections.length, linked_term_ids: [] }])}>Add section</button>
        </fieldset>
      </> : type === "flashcard" ? <>
        {text("front", "Front", true, true)}
        {text("back", "Back", true, true)}
        {select("linked_content_id", "Related medical term (optional)", options.terms, false)}
      </> : term ? <>
        {text("term", "Medical term")}
        <label>Simple definition<textarea rows={4} value={String(definitions.simple ?? "")} onChange={e => set("definitions", { ...definitions, simple: e.target.value })} required /></label>
        <details className="editor-optional"><summary>More definitions and search names (optional)</summary><div className="form-grid">
          <p className="muted">If left blank, the other reading levels use your simple definition.</p>
          {(["standard", "technical"] as const).map(key => <label key={key}>{key === "standard" ? "Standard definition" : "Technical definition"}<textarea value={String(definitions[key] ?? "")} onChange={e => set("definitions", { ...definitions, [key]: e.target.value })} /></label>)}
          {lineList("synonyms", "Other names (one per line)")}
          {lineList("alternative_spellings", "Alternative spellings (one per line)")}
          {lineList("lay_terms", "Everyday names (one per line)")}
          {lineList("abbreviations", "Short names (one per line)")}
        </div></details>
        {select("language", "Language", [{ id: "en", name: "English" }, { id: "ur", name: "Urdu" }])}
        {lineList("examples", "Examples (one per line)")}
      </> : type === "morphology" ? <>
        {select("type", "Word part type", [{ id: "prefix", name: "Prefix — beginning of a word" }, { id: "root", name: "Root — main part of a word" }, { id: "suffix", name: "Suffix — end of a word" }])}
        {text("value", "Word part")}
        {text("meaning", "Meaning")}
        {text("explanation", "Simple explanation", true, true)}
        {lineList("examples", "Examples (one per line)")}
        {text("category", "Topic", true)}
        {text("origin", "Word origin (optional)", false)}
        {select("language", "Language", [{ id: "en", name: "English" }, { id: "ur", name: "Urdu" }])}
      </> : type === "abbreviation" ? <>
        {text("abbreviation", "Abbreviation")}
        {text("expansion", "Full meaning")}
        {select("term_id", "Related medical term", options.terms)}
        <p className="muted">The reference source comes from the related medical term.</p>
        {text("context", "Where it is used", true, true)}
        {text("category", "Topic")}
        <label className="editor-check"><input type="checkbox" checked={Boolean(data.ambiguous)} onChange={e => set("ambiguous", e.target.checked)} />This abbreviation can have more than one meaning</label>
        {data.ambiguous ? lineList("alternative_meanings", "Other possible meanings (one per line)", true) : null}
        {text("safety_warning", "Important clarification (optional)", false, true)}
      </> : type === "quiz" ? <>
        {text("prompt", "Question", true, true)}
        {text("explanation", "Explanation of the correct answer", true, true)}
        <fieldset><legend>Answer choices</legend><p className="muted">Add at least two answers and select the correct one.</p>
          {answers.map((answer, i) => <div className="editor-item form-grid" key={i}>
            <label>Answer {i + 1}<input value={String(answer.text ?? "")} onChange={e => set("options", answers.map((a, index) => index === i ? { ...a, text: e.target.value } : a))} required /></label>
            <label className="editor-check"><input type="radio" name="correctAnswer" checked={Boolean(answer.correct)} onChange={() => set("options", answers.map((a, index) => ({ ...a, correct: index === i })))} required />Answer {i + 1} is correct</label>
            <button className="button secondary" type="button" disabled={answers.length <= 2} onClick={() => {
              const remaining = answers.filter((_, index) => index !== i);
              if (!remaining.some(a => a.correct)) remaining[0] = { ...remaining[0], correct: true };
              set("options", remaining);
            }}>Remove answer {i + 1}</button>
          </div>)}
          <button className="button secondary" type="button" onClick={() => set("options", [...answers, { id: `answer-${crypto.randomUUID()}`, text: "", correct: false }])}>Add answer</button>
        </fieldset>
        {select("linked_term_id", "Related medical term (optional)", options.terms, false)}
      </> : null}
    </fieldset>
    {!dataset && type !== "abbreviation" ? <fieldset disabled={pending}>
      <legend className="editor-heading">2. Organisation and reference</legend>
      {data.category_id !== undefined ? select("category_id", "Category", options.categories) : null}
      {data.difficulty !== undefined ? select("difficulty", "Difficulty", difficulties) : null}
      {type !== "abbreviation" ? <>
        {select("source_id", "Reference source", options.sources.map(s => ({ id: s.id, name: s.title })))}
        {reference?.reference ? <p className="muted">Source: {reference.reference}</p> : null}
        {!options.sources.length ? <p className="error">No reviewed reference sources are available. A source must be prepared before this content can be published.</p> : null}
      </> : null}
    </fieldset> : null}
    <fieldset disabled={pending}><legend className="editor-heading">{dataset ? "Review note" : type === "abbreviation" ? "2. Save for review" : "3. Save for review"}</legend>
      <label>Change reason<textarea name="reason" rows={2} minLength={3} maxLength={1000} placeholder={stableId ? "What did you update?" : "Why are you adding this content?"} defaultValue={stableId ? "" : "Add new reference content"} required /></label>
      <button disabled={pending || readingFile || Boolean(fileError) || (dataset && !data.dataset_version) || (type === "lesson" && !sections.length)}>{pending ? "Saving…" : "Save draft revision"}</button>
    </fieldset>
    <details className="editor-optional"><summary>Record information</summary><p className="muted">Record ID: {string("id") || computedId || "Generated automatically when you enter content"}</p><p className="muted">Existing record numbers are retained when you edit. Saving a draft does not change the published mobile content.</p></details>
  </form>;
}
