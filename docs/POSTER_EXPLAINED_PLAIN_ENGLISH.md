# MediExplain poster explained from the beginning

This is a plain-English study guide to the one-page **MediExplain medical literacy exhibition poster** supplied on 21 October 2026. It follows every numbered section, explains the small labels and technology logos, and connects the ideas to the current project code.

Read sections 1 and 2 first if software terms are new to you. Then follow the poster from section 3 onward. Section 12 explains the graph, which needs especially careful answers. Section 17 contains short examiner answers.

Source poster: `/Users/mahdiahrari/Downloads/MediExplain medical literacy exhibition poster.pdf`. The poster was visually inspected, including enlarged workflow, technology-stack, and graph areas. Its text is embedded as an image, so ordinary PDF text extraction did not capture it. The original poster has not been edited.

## 1 The project in the simplest possible words

**MediExplain helps a patient understand medical language and reviewed medicine information, organize their medicines, and remember their own medication schedule.**

Imagine a patient called Ali. This is an invented teaching example, not a patient record:

1. Ali sees a difficult medical word and searches for its meaning.
2. He photographs a prescription.
3. The application recognizes the writing and organizes medicine-related information.
4. Ali checks and corrects what was recognized.
5. After confirming the medicine list, he requests simple explanations.
6. The backend finds supporting reference information and prepares explanations.
7. Ali can add reviewed medicines to My Medications and choose reminder settings.
8. When a reminder appears, he can record Taken or Skipped.

The important connection is **understanding + review + organization**. The system does not independently decide what disease Ali has or prescribe a treatment.

An opening answer you can say aloud:

> “MediExplain is a patient-facing medical literacy and medication-support application. It combines terminology learning, prescription reading with human review, source-backed medicine explanations, and personal medication reminders. It stores many everyday records locally, while online services support authentication, reference retrieval, and cloud AI.”

## 2 Basic words you need before reading the poster

### Application program and code

An **application** is software somebody uses, such as your phone app. A **program** is a set of instructions a computer follows. **Source code** is those instructions written in a programming language.

A **file** holds code or other information. A **folder** organizes files. A **module** is a group of related responsibilities, such as prescription scanning. A module may contain many files; it does not mean one file or one AI model.

### Language framework library and platform

- A **programming language** is how instructions are written. Your mobile code uses Dart; the backend uses Python.
- A **framework** supplies an organized foundation for an application. Flutter helps build the mobile interface; FastAPI helps build HTTP services.
- A **library** is reusable code for particular jobs. A camera or HTTP package is a library/dependency.
- A **platform** is an environment where software runs, such as Android or iOS. The poster also uses “platform” more broadly for the connected MediExplain system.

### Frontend backend and server

The **frontend** is what the user sees and interacts with: pages, buttons, forms, and results. Your Flutter mobile application is the patient frontend.

The **backend** performs server-side work: checking credentials, reading shared reference data, calling AI providers, validating results, and storing supported server records.

A **server** is a program/computer that responds to requests. In your development setup, the Mac hosts the backend. A server does not have to be a large machine in a data center. A future deployment could use a hosted server.

### API request response and JSON

**API** means Application Programming Interface. Think of it as an agreed doorway through which one program asks another to do something.

For login:

```text
Phone asks: “Please check these login details.”
Backend processes the request.
Backend replies: “Login succeeded; here is a session,” or returns an error.
```

The outgoing message is a **request**. The reply is a **response**. An **endpoint** is one API address for a particular job, such as `/api/v1/auth/login`.

**JSON** is a common text format for exchanging named values. For example, `{"name": "Medicine A"}` has the field `name` and its value. This placeholder illustrates message structure; it is not an actual medicine reference.

### Database table record and identifier

A **database** stores organized information. A **table** groups a kind of information, such as prescriptions. A **record** is one stored item. An **ID** uniquely identifies a record so the program does not confuse two items with the same display name.

Your phone uses SQLite, accessed through Drift. Your backend uses PostgreSQL, accessed through SQLAlchemy. A patient medication record is different from a general reference entry about that medicine.

### Local remote cloud and offline

- **Local/on-device:** happens on the phone, or on another specifically named local machine.
- **Remote:** happens on a different machine reached through a network.
- **Cloud:** hosted computing services reached over the internet, such as Gemini or Groq.
- **Offline:** no usable network connection for the operation in question.

“Local AI” in this project means the configured Ollama model runs on the **Mac**, not inside the iPhone. “On-device OCR” means recognition runs on the **phone**. Those are different locations.

### State validation and error handling

**State** means the application's current situation: loading, ready, signed in, waiting for review, or failed.

**Validation** means checking that an input/result follows rules. For example, a medicine batch must have unique item IDs and confirmed entries.

**Error handling** means deciding what happens when a step fails: keep the draft, show a message, allow correction, or retry. It is part of functionality, not an optional extra.

## 3 The heading and subtitle

### MediExplain

The name combines a medical idea with explanation. It tells visitors the application helps people understand medical information.

### “An Offline-First Medical-Literacy and Medication Support Platform with Source-Grounded AI”

This sentence contains the main design claims. Understand each part:

| Phrase | Meaning | Example in your project |
| --- | --- | --- |
| Offline-first | Many ordinary actions use local storage first rather than waiting for a server request. | Read installed lessons or view locally saved medication records without a new cloud call. |
| Medical literacy | Understanding medical words and information well enough to make sense of them and discuss them. | Look up a difficult term and read a simple definition. |
| Medication support | Help organizing medicine information and the user's reviewed schedule/history. | Save a medicine, set a reminder, record Taken or Skipped. |
| Platform | Several connected components working together. | Flutter app, backend, local/server databases, and external provider adapters. |
| AI | Software models used for tasks such as recognizing writing or producing understandable text. | Cloud prescription reading and supported grounded explanation generation. |
| Source-grounded | The explanation is constrained by retrieved reference information rather than being accepted just because a model generated it. | Resolve the medicine, collect source facts, generate/check an answer, and show citations. |

**Offline-first does not mean everything works offline.** New cloud image reading needs a reachable backend and external service. Installed content, existing local records, and already-scheduled supported notifications are different operations.

**Source-grounded does not mean guaranteed correct.** Identity matching, source relevance, and interpretation can still fail. Sources and review reduce some risks; they do not create clinical certification.

### University student supervisor and exhibition heading

Quaid-i-Azam University, the student name, registration number, supervisor, and InnovateX 26 exhibition branding identify the project and its academic context. They are not software modules or claims of medical approval. “Ideas Today, A Brighter Tomorrow” is exhibition branding.

## 4 Poster section 1 Implemented Modules

The six cards describe six related groups of functions. They should be explained individually before you explain how they connect.

### 4.1 Terminology Search and Learning

**Terminology** means specialized words. Medical terminology includes words used in reports, conditions, and clinical conversations. An **abbreviation** is a shortened expression. Abbreviations can have multiple meanings, so surrounding context matters.

The app searches installed terms and shows available definitions. A simple explanation uses everyday language. A technical explanation uses more specialized detail. Changing explanation depth should change the level of detail, not secretly change the underlying fact.

Example from the installed educational corpus: “hypertension” is associated with the everyday expression “high blood pressure.” This teaches the meaning of a word; typing the word does not diagnose the user.

Learning includes:

- **Lessons:** small units of teaching content with saved progress.
- **Flashcards:** a prompt on one side and an answer revealed afterward.
- **Quizzes:** questions that check what the learner understood.
- **Word breakdowns:** supported prefixes, roots, and suffixes. For example, the stored parts of `tachycardia` include “fast,” “heart,” and “condition/state.”

An algorithm is a sequence of steps for solving a task. The flashcard algorithm adjusts future review times from Again/Hard/Good/Easy ratings. The quiz engine compares selected option IDs with correct sets. These algorithms do not need an AI model for every interaction.

**Where in the code:** `features/terminology/`, `features/learning/`, and the two JSON content assets under `assets/terminology/`.

**Say aloud:** “This module lets users search medical terms, read meanings at different levels, and learn through stored lessons, flashcards, and quizzes.”

### 4.2 Prescription OCR and Review

**Prescription** means the written medicine-related instructions being captured. **OCR** means Optical Character Recognition: turning visible writing in an image into computer-readable text.

An image is a grid of pixels. OCR attempts to recognize letters, words, and their positions. The returned text can then be edited, searched, or organized. Simply taking a photo does not make its text searchable.

**Review** means the user sees the recognized result and compares it with the original. Common errors include confusing a letter, missing a line, attaching the wrong strength to a medicine, or reading an instruction as a name.

**OCR is not the same as parsing or medical verification:**

```text
OCR: “What writing can be recognized?”
Parsing: “Which pieces are the name, strength, form, and instructions?”
Review: “Has the user checked and corrected this result?”
Identity resolution: “Which reference medicine does this entry correspond to?”
```

In the current app, Check opens an editor, Confirm records reviewed state, and a separate action requests explanations after the retained list is confirmed.

**Where:** `prescription_workflow_controller.dart`, the prescription review/edit screens, and backend OCR/structuring services.

**Say aloud:** “The module recognizes prescription writing and organizes it for review. It does not silently treat OCR text as a verified medication instruction.”

### 4.3 Medicine Information

This module retrieves supported information about a medicine identity. A **generic/ingredient name** identifies the active substance. A **brand name** identifies a marketed product name. A brand may have several variants; matching the brand text alone may not identify the exact formulation.

Keep these fields separate:

| Field | What it describes |
| --- | --- |
| Name | The medicine/product being referred to. |
| Ingredient | Active substance or substances in the medicine. |
| Strength | Amount/concentration of ingredient per unit, as supported by the source or written instruction. |
| Form | Tablet, capsule, liquid, cream, or another presentation. |
| Dose quantity | Amount taken at a particular administration, as written and reviewed. |
| Frequency | How often the written instruction says an administration occurs. |
| Duration | How long the instruction applies, if readable/present. |

For a units-only illustration, `mg` describes a mass unit, `tablet` describes a form/unit, and `per day` describes time. A strength is not automatically the patient's dose. This explanation supplies no treatment schedule.

“Reliable medicine facts and details” means evidence from supported references with identity/provenance checks. It does not mean every regional brand or handwriting spelling is recognized.

**Where:** `features/intelligence/`, `medication_intelligence.py`, medicine-name resolution, and medical-source provider adapters.

### 4.4 AI Explanation with Citations

An **explanation** puts relevant information into understandable sentences. A **citation** identifies supporting source material so the user can inspect it.

A useful analogy: a student receives a few approved textbook passages and writes a short summary. The textbook passages are the evidence; the student's summary is new wording. In your app, the model is the summary writer, not the authority that makes a drug fact true.

The backend:

1. Resolves an appropriate medicine identity.
2. Retrieves/selects supporting facts.
3. Supplies facts and source identifiers to the model.
4. Requests a structured result.
5. Checks permitted identities, source IDs, numbers, and other output constraints.
6. Returns an explanation or an appropriate source/unavailable/correction state.

This is a retrieval-augmented generation pattern, often shortened to **RAG**. Your current retrieval is based on relational facts and application selection logic; do not invent a vector database or claim you trained the model on patient records.

The citation checks are useful but do not prove every sentence is faithfully supported. Full semantic and clinical validation remains a stronger requirement.

**Where:** `medicine_batch_overview.py`, `medical_rag.py`, AI provider adapters, and the separate mobile explanations page.

**Say aloud:** “AI helps simplify retrieved information. The application supplies and validates source references instead of allowing the model to invent citations.”

### 4.5 Reminders and History

A **reminder** is a scheduled phone alert. A **history record** stores a dated user action.

These are related but different:

- A medicine record says what the user saved.
- A plan holds reviewed instruction/date context.
- A schedule stores chosen times or supported recurrence rules.
- A dose event records Taken, Skipped, or another supported status.

The schedule engine computes due times, the reminder service organizes a bounded future notification window, and the notification adapter asks the operating system to schedule alerts. The history repository saves user actions.

The poster's “dosage history” should be explained as **recorded medication/dose-event history**. It is not a history of AI-prescribed dose changes and not proof that a pill was physically swallowed.

**Where:** `schedule_engine.dart`, `medication_reminder_service.dart`, `notification_service.dart`, and `local_medication_repository.dart`.

### 4.6 Offline-First Local Data

**Local storage** keeps information on the device. **Persistence** means the information survives closing and reopening the app.

For example, after a reviewed medicine is saved locally, the phone does not need to fetch the same personal record from the server for every display. Installed learning content also remains available.

Supported changes can enter an **outbox**, a queue of work waiting to be uploaded. On a suitable connection and with synchronization enabled, the app sends eligible operations. A failed send can retry later.

**Caching** means temporarily keeping a copy of information to avoid another lookup. Cached external information can become stale, so age/version/state still matter.

Do not describe the outbox as complete two-way merging between arbitrary devices. Its actual scope is the supported operations in the transport code.

**Where:** Drift database files, account database selection, local repositories, and `sync_coordinator.dart`.

## 5 Poster section 2 Problem Statement

A problem statement explains why the project is needed. It does not describe the implementation tool first.

### “Medical terms and abbreviations are difficult for many users to understand”

A patient may recognize individual words but not their clinical meaning. An abbreviation may have more than one interpretation. The corresponding feature is searchable terminology, plain-language meanings, and explicit ambiguity handling.

**Example:** a person understands “high blood pressure” more easily than a specialized term. The application links the language, without claiming that the person has the condition.

### “Prescription information is often fragmented and hard to organize”

**Fragmented** means information is scattered across the page or among records. A photograph can contain several medicine rows, dates, names, and unrelated headings.

The corresponding features are capture/import, separate medicine items, structured fields, review, and saved medication records.

### “Unreviewed OCR and unverified AI responses can create uncertainty”

OCR may read the wrong text. AI may produce a fluent but unsupported answer. A response can sound confident while being wrong; this is often called a **hallucination** in generative AI.

The corresponding controls are uncertainty states, correction, explicit confirmation, medicine identity resolution, retrieved facts, output checks, and citations.

### “Users need understandable medicine information with visible sources”

An answer that cannot be traced to its source is harder to assess. Visible sources let the user see where information came from, which product it concerns, and whether it is current/relevant.

**Say aloud:** “The problem is not just reading text. It is helping people understand and organize the right information while exposing uncertainty and evidence.”

## 6 Poster section 3 Objectives

An **objective** is what the project aims to accomplish. Match each objective to a demonstrable feature.

| Poster objective | Plain meaning | How it connects to the project |
| --- | --- | --- |
| Provide searchable medical terminology with simple and technical explanations. | Let people find medical words and choose suitable detail. | Search, term detail, definition levels, abbreviations, morphology. |
| Support learning through lessons, flashcards, and quizzes. | Help users understand and remember information over time. | Installed content, saved lesson progress, review scheduling, scoring. |
| Extract prescription text locally and require user review before use. | Read writing and have the user check it. | Local OCR exists, but the current normal image workflow uses cloud reading. Review remains part of the current flow. |
| Deliver source-backed medicine explanations and reminder planning. | Explain supported medicine information and help organize reviewed schedules. | Reference providers, batch explanations, medication plans, local alerts. |
| Support offline use, synchronization, and governed admin workflows. | Keep local functionality, upload supported changes, and control administrative content actions. | Local database/outbox and admin API governance. The web admin frontend is absent here. |

Be especially careful with objective three: local extraction is a design/capability shown on the poster, not a correct description of every current scan. Do not say cloud-uploaded images never leave the phone.

## 7 Poster section 4 Methodology and System Workflow

**Methodology** means the organized approach used to address the problem. **Workflow** means the sequence of steps and information movement.

The arrows mean “information/work proceeds to this stage.” They do not mean the user has to press a separate button for every box. The diagram is conceptual; it does not show every HTTP request, database operation, or failure route.

### 7.1 User to Mobile App Flutter

The user starts with the phone interface. Flutter draws the screens, receives taps, displays progress, and renders results. The backend does not draw the Flutter screen.

### 7.2 The terminology search and learning branch

The upper branch represents a route that does not need a prescription photo:

```text
Open Learn/Search → search or choose content → read meaning/lesson
  → review flashcards or answer quizzes → save progress
```

Many of these operations use local content. This branch is separate from prescription capture and is one reason the app has value even when cloud scanning is unavailable.

### 7.3 Capture or Import

**Capture** means take a new picture. **Import** means select an existing image from a supported source.

Inputs: image(s). Outputs: private image references/pages. Preparation can include orientation correction, supported crop/rotation, resizing, and quality estimates.

Preparation helps the reader but cannot restore handwriting information that is genuinely absent, covered, or unreadable.

### 7.4 On-device OCR Google ML Kit

In the diagram, recognition occurs on the device through ML Kit. ML Kit is Google's developer toolkit; its text-recognition component detects readable text and related structure. It is not a general-purpose medicine explanation system. See [Google's text-recognition documentation](https://developers.google.com/ml-kit/vision/text-recognition/v2).

Current code distinction:

- Android native on-device recognition uses ML Kit.
- iOS native on-device recognition uses Apple Vision.
- The normal current prescription processing screen selects backend cloud reading, with Gemini/Groq routing for supported availability failures.
- A separate optional CPU handwriting reader uses TrOCR-small on the server.

The poster captures an earlier/local path. Explain both the diagram and the latest implementation when asked.

### 7.5 Structured Parsing

**Parsing** means turning input into an organized representation.

Imagine this non-clinical placeholder row:

```text
Medicine A | strength as written | form as written | instruction as written
```

The software turns it into separate named fields rather than one undifferentiated paragraph. Headings and addresses should not become medicine entries.

A **schema** checks required keys/types, and additional evidence checks compare extracted fields with recognized text. A valid JSON shape alone is not proof of correct reading. For example, a perfectly formed `name` field can still contain the wrong name.

Current structuring may use cloud AI plus validation; local conservative parsers also exist. Do not describe the complete modern flow as only a fixed regular expression or only a single model call.

### 7.6 User Review and Confirmation

The user inspects name, strength, form, dose quantity, frequency, and other readable fields. Check lets them edit. Confirm records review.

Confirmation is important because the next stages should not blindly depend on an unreviewed guess. It is still a user action, not certification by a doctor or pharmacist.

### 7.7 Medicine Lookup

The program tries to connect the reviewed name/details to a supported medicine identity. This is **resolution** or **normalization**.

**Normalization** means representing equivalent information consistently. Different spellings/labels may refer to the same supported concept, while two products with a similar name may differ in strength, form, or ingredients.

A search result's ranking is not proof of equivalence. Missing identity or conflicting candidates must remain visible as an unresolved/selection/correction case.

### 7.8 Source Facts RxNorm DailyMed Reviewed DRAP Imports

These are different resources with different purposes:

| Source | What it is | Why your app uses it | What it does not establish by itself |
| --- | --- | --- | --- |
| RxNorm | NLM's system of normalized drug names and identifiers, including ingredient/strength/form concepts where applicable. | Resolve consistent medicine concepts and relationships. | A complete patient explanation for every regional product or an individual's treatment plan. |
| DailyMed | NLM's searchable collection of drug labeling submitted to the FDA and currently in use. | Retrieve relevant label facts and supporting references. | That every listed product is FDA-approved or that its label is personalized advice for the user. |
| DRAP | Drug Regulatory Authority of Pakistan. Here the software supports controlled imports of relevant product data. | Represent supported local product identities and registration-related information. | That an arbitrary uploaded CSV is genuine, current, clinically reviewed, or equivalent to a foreign product. |

References: [RxNorm overview](https://www.nlm.nih.gov/research/umls/rxnorm/overview.html), [DailyMed about](https://dailymed.nlm.nih.gov/dailymed/about-dailymed.cfm), [DRAP about](https://www.dra.gov.pk/about-us/).

**Reviewed import** should mean an authorized person checked a legitimate source, version, required fields, duplicates, relationships, and the staged report before applying the data. The implementation supports parsing, dry-run jobs, confirmed application, and audit records. That infrastructure does not prove all possible input records have undergone independent review.

MedlinePlus is also supported in code, although the workflow box does not list every provider.

### 7.9 Optional AI Explanation Qwen3 and Qwen3 8B

**Optional** means generation is a layer on top of evidence, not the source that establishes the medicine identity. Where supported, original source text can still be shown if generation fails or is rejected.

**Qwen3** is a model family. `qwen3:8b` names a particular model variant/tag, not an entirely separate technology from Qwen3. The poster reflects the earlier local setup. The current default configuration is Gemini first, supported Groq cloud fallback, and local Ollama `qwen3:1.7b` for supported text fallback.

All retained medicines are confirmed before the separate Explain action. The current prescription page sends a complete list for one AI generation batch; it does not intentionally request a separate explanation just because each Confirm button was tapped.

### 7.10 Medication Reminders and Saved Records

The final box stores useful reviewed records and organizes the user's chosen reminder settings. It does not mean the model automatically invents reminder times from incomplete handwriting.

The diagram has arrows toward saving/reminders from the reviewed-data path as well as the information path. The important idea is that reviewed prescription records and sourced explanations support the same application, while saving/organizing data is distinct from generating new medical advice.

### 7.11 The current complete flow in one readable chain

```text
Photo/import
  → image preparation
  → cloud reading in the normal current flow
  → recognized text
  → medicine structuring and validation
  → local draft and review
  → user correction and confirmation
  → whole-list Explain action
  → exact reference resolution and relevant facts
  → optional AI batch and output checks
  → separate named explanations
  → reviewed medication saving and user-configured reminders
```

## 8 Poster section 5 Results and Output App Interface

This panel shows examples of what a person can see/use. It is not an accuracy study.

### The pictured home screen

- **MediExplain / A clearer path through medical language:** product name and introductory message.
- **What would you like to understand today?:** invites a user action.
- **Next medication reminder:** shows the nearest available supported reminder. “No upcoming fixed reminder” is an empty state, not a failure by itself.
- **Search medicine information:** opens supported medicine lookup/reference information.
- **Today's reminders:** helps users see due tasks and related records.
- **Settings gear:** a familiar symbol for application preferences.
- **Home / Scan / Learn / Saved / Profile:** bottom navigation to the main areas.

The clock and phone status icons are device/screenshot decoration. They are not performance measurements or proof of a live backend connection.

### Key Outputs Demonstrated

| Poster item | Observable output |
| --- | --- |
| Medical terminology learning and search | A list of matching terms, an explanation, or learning activity. |
| Prescription capture and OCR review | A captured/imported image and recognized information that can be reviewed. |
| Source-backed medicine information | Medicine identity/details accompanied by available reference information. |
| AI explanation with citations | Understandable explanation and traceable supporting references. |
| Reminder scheduling and dose history | Saved reminder settings and dated user dose events. |
| Offline-first local data behavior | Existing supported local content and records remain usable without a fresh online lookup. |

If asked about results, distinguish three things: a screenshot demonstrates an interface, an automated test checks a scenario, and a clinical/accuracy evaluation measures performance on an appropriate dataset or user study. One does not replace the others.

## 9 Poster section 6 Technology Stack

**Technology stack** means the collection of languages, frameworks, databases, platforms, and tools used together.

The poster uses logos instead of writing every name. Explain what each symbol represents and its actual status here.

### 9.1 Mobile Application logos

**Flutter: the angular blue F symbol.** A framework for building application interfaces with Dart. A Flutter screen is built from widgets: reusable pieces such as text, buttons, lists, cards, and whole layouts. Your shared screens are in `apps/mobile/lib/`. [Flutter architecture](https://docs.flutter.dev/resources/architectural-overview).

**Android: the green robot.** A mobile operating system/platform. The native Android folder declares permissions/build settings and contains the Kotlin bridge for scanning/OCR. Android is not the programming language used for most of your screens.

**Apple: the black Apple symbol.** Here it represents iPhone/iOS platform support, not proof of iCloud integration or App Store publication. The Swift bridge and iOS configuration live in `apps/mobile/ios/`. Shared Flutter code does not remove the need for signing, permissions, native integration, and real device tests.

**Dart: the blue geometric language symbol.** The programming language used by your Flutter code. Language and framework are connected but not identical: Dart expresses instructions; Flutter supplies the UI framework.

### 9.2 Backend and Database logos

**Python: the blue/yellow symbol.** The programming language used for server code, validation/services/provider adapters, and utilities. Python is not the database.

**FastAPI: the green lightning symbol.** A Python web framework used to expose API routes and integrate validated data/dependencies. It receives HTTP requests and returns responses. Your `app/main.py` creates the app through `factory.py`; Uvicorn serves it. The name does not guarantee every external AI call finishes quickly. [FastAPI documentation](https://fastapi.tiangolo.com/).

**PostgreSQL: the elephant.** The server's relational database system. “Relational” means data is organized into connected tables. Accounts, sessions, prescriptions, plans, reference facts, and governance records have different responsibilities and relationships.

**The blue cylinder: a general database/storage symbol.** The poster does not spell out a second database name beside it. The actual code uses SQLite through Drift on the phone as well as PostgreSQL on the server. Do not identify the cylinder as a specific product solely from its shape.

Related code tools that are not individually labeled on the poster:

- **SQLAlchemy:** Python's table mappings and database query/session machinery.
- **Pydantic:** checks the shape and allowed content of API messages.
- **Alembic:** applies ordered server database migrations.
- **Drift:** typed/local database access and generated SQLite mapping code in Dart.

### 9.3 Web Admin Portal logos

**Next.js: the N symbol.** A React-based web application framework that can provide routing and server-side web functionality. **React: the atom-like symbol.** A library for building web interfaces from components. **TypeScript: TS.** A language that adds type checking to JavaScript development. **Globe:** a general web/browser symbol, not a separate AI model.

Together, those logos describe a web administration frontend design: a person uses a browser to review content, stage imports, publish reviewed data, or inspect system information. [Next.js docs](https://nextjs.org/docs), [React components](https://react.dev/learn), [TypeScript introduction](https://www.typescriptlang.org/docs/handbook/typescript-in-5-minutes.html).

**Current status:** `apps/admin` is absent from this checkout. Admin backend routes, permissions, workflows, and audit models exist. You can explain the architecture, but do not claim an included, runnable admin website has been verified.

### 9.4 AI and Tools logos

**Ollama: the llama symbol.** Software that can run/download models and expose an API. In your configured local fallback, Ollama serves Qwen on the Mac. Ollama is the runner; Qwen is the model. The phone can access that capability indirectly through the backend. Ollama can support different deployment modes; the word “Ollama” alone is not a guarantee every request is local. [Ollama documentation](https://docs.ollama.com/).

**Qwen: the purple symbol.** A pretrained model family from the Qwen team at Alibaba Cloud. In the poster's local text path it helps generate explanations from supplied text context. It is not a medicine-reference authority. Ordinary text-only Qwen3 is not a prescription image reader. [Qwen3 project](https://github.com/QwenLM/Qwen3).

**OpenAI: the green interlocking symbol.** Identifies the OpenAI ecosystem. The actual code contains an OpenAI-compatible adapter, and the configured Groq text model identifier is `openai/gpt-oss-120b`. These facts do not prove the backend is directly calling OpenAI's hosted API. “Compatible” describes a request/response interface; another service can implement it.

**Docker: the whale carrying containers.** A tool for packaging/running backend services in containers. An image is a packaged template; a container is a running instance. Compose connects services such as the API and PostgreSQL. Persistent database storage is separate from an expendable container. Docker does not run your Flutter patient screens on the iPhone. [Docker overview](https://docs.docker.com/get-started/docker-overview/).

### 9.5 Extra terms examiners may ask about the current AI setup

**Gemini:** the primary configured cloud AI provider for current supported reading/structuring/text paths. **Groq:** a cloud provider used for supported quota/temporary-availability fallback. They are not the same service. **API key:** a server-side credential allowing requests to a provider. **Quota/rate limit:** a provider-imposed usage allowance or request rate.

**Fallback** means switch to an appropriate alternative after certain failures. A text fallback is not automatically an image fallback. Invalid credentials, unsafe output, and quota failure are different cases; do not call all failures “the limit.”

## 10 Parameters training inference and memory

These ideas explain the model labels in the poster.

### What is a model

An AI model is a trained computational system used to transform inputs into outputs. For a language model, the input includes text context/instructions and the output is generated text.

**Training** changes learned model weights using data and an optimization process. **Inference** uses existing weights to produce an output. **Integration** connects a pretrained model to your application.

Your project integrates pretrained models. It does not show that you trained Gemini, Qwen, or ML Kit from scratch. Collecting local medical reference facts is also not the same operation as training a neural network.

### What does 8B mean

`8B` means approximately eight billion learned parameters. A parameter is a numerical value learned during training. It is not eight billion patient records, eight billion lines of your code, eight GB exactly, or an eight-percent accuracy score.

`1.7B` is a smaller parameter-count variant. Fewer parameters can reduce memory/computation needs, but speed and usefulness also depend on implementation, context length, hardware, and quantization.

### What is RAM and why was 8B heavy

RAM is working memory used while programs run. The operating system, browser, Docker, API, database, model, and other applications all share the Mac's finite memory.

For an arithmetic illustration only: eight billion numbers stored at two bytes each require about sixteen billion bytes for those numbers alone. Quantization can reduce the storage per weight. Real runtime memory also includes additional state and overhead. Therefore “8B” does not directly tell you the final RAM requirement or exact downloaded file size.

**Quantization** stores numerical values more compactly, trading precision/implementation considerations for lower resource use. **Context** is the information supplied to the model for the request, including source passages and questions. Larger context also consumes resources.

The current configuration's local model is `qwen3:1.7b`, chosen as a lighter text fallback. This guide verifies that default in code; it does not perform a fresh model-runtime health check.

## 11 Actual implementation versus poster wording

Memorize this table before the viva so you can reconcile the poster with your current demo.

| Poster wording or implication | Accurate current explanation |
| --- | --- |
| On-device OCR using Google ML Kit in the main image chain | Android has ML Kit support; iOS native support uses Apple Vision. Normal prescription processing currently chooses backend cloud reading. |
| Extract prescription text locally | A supported local capability/design objective; current normal cloud reading uploads the image. |
| Qwen3 / Qwen3:8B explains medicines | Earlier setup shown on the poster. Code defaults now use Gemini/Groq and supported local Qwen3 1.7B text fallback. |
| A web admin portal is part of the technology stack | Described/intended frontend; its source is absent here. Backend admin functionality is present. |
| OpenAI logo implies direct OpenAI API calls | A logo is insufficient. There is compatible-adapter support and a Groq-hosted model with an OpenAI author identifier. |
| Offline-first means all AI works without connectivity | Existing local operations/content remain available; cloud calls need connectivity and the Mac must be reachable for Mac-hosted services. |
| Reviewed DRAP imports imply all bundled data is verified | Controlled import/review machinery exists. Individual records still need legitimate provenance and appropriate review. |
| The graph proves measured superiority | The poster gives suitability numbers without a measurement method/sample size. No supporting scoring study was found in the inspected project material. |

A simple sentence to use:

> “The poster shows the earlier local architecture and the overall system roles. The current demo adds cloud handwriting reading and Gemini/Groq routing, with a smaller local text fallback. I separate those implementation updates from the conceptual design shown here.”

## 12 Poster section 7 Model Comparison in MediExplain

### 12.1 What the graph literally shows

The vertical axis is **Suitability**, from zero to five. The horizontal categories are **OCR capability**, **Explanation generation**, **Local execution**, and **Source-grounded response**. Dark teal represents Google ML Kit; light turquoise represents Qwen3:8B.

| Category | ML Kit bar | Qwen3:8B bar |
| --- | ---: | ---: |
| OCR capability | 5 | 1 |
| Explanation generation | 1 | 5 |
| Local execution | 5 | 4 |
| Source-grounded response | 1 | 5 |

This table transcribes the displayed values; it does not validate them.

### 12.2 How to understand the intended role comparison

**OCR capability:** ML Kit's text recognizer is designed to read supported text from images. A text-only Qwen3 model is not an image recognizer. The useful lesson is that reading images and generating prose are different jobs. A bar labeled 1 should not be taken as evidence of one-fifth image-reading accuracy.

**Explanation generation:** OCR returns recognized content; it is not intended to write a new patient explanation. A language model can produce explanations from supplied text. The bars illustrate different roles, not a measured guarantee of five-star medical correctness.

**Local execution:** supported ML Kit recognition can run on the phone. Qwen3:8B can run locally on suitable hardware through a runner, but the earlier Mac setup had a higher memory burden. Here, “local” refers to different devices. The 5-versus-4 values lack a documented timing/memory rubric.

**Source-grounded response:** a language model can be placed in a source-grounded pipeline, whereas OCR alone is not such an answering system. Crucially, **grounding is supplied and checked by the application; it is not guaranteed by the Qwen model name**. A 5 on this bar cannot prove the model always cites correctly.

### 12.3 What you must not claim

- “ML Kit has 100% prescription accuracy.”
- “Qwen3 is 100% medically correct.”
- “Five means 95% or 100% accuracy.”
- “These exact scores came from a clinical trial,” unless you have actual trial evidence.
- “Qwen3 8B is the current model on the Mac,” based only on the poster.
- “ML Kit and Qwen are interchangeable alternatives for the same task.”

I found no dataset, scoring rubric, sample size, uncertainty estimates, or benchmark report supporting those exact 1–5 values in the inspected material. Without additional evidence, describe it as an **illustrative functional comparison**, not quantitative experimental results.

### 12.4 Strong answer if challenged about the numbers

> “The graph illustrates the roles of the earlier OCR and language-generation components. It is not an accuracy benchmark. ML Kit handles image text recognition, while the language model handles text generation inside our retrieval and validation pipeline. For an experimental comparison I would need a labeled dataset, a defined metric, measured hardware/latency conditions, and a scoring procedure.”

If asked what you would measure, explain these in plain terms:

| Evaluation | Plain meaning |
| --- | --- |
| Character error rate | How many character edits are needed to turn recognized text into the correct text, relative to reference length. |
| Word error rate | The same general idea at word level, using insertions, deletions, and substitutions. |
| Medicine-field accuracy | Whether the correct name/strength/form/instruction is attached to the correct medicine row. |
| Missed medicines | How many genuine medicine entries were not extracted. |
| Unsupported additions | How many entries/details were produced without corresponding evidence. |
| Citation support | Whether cited sources actually support the displayed medicine and statements. |
| Latency | How long the task takes, with network/hardware/provider conditions stated. |
| Memory use | How much working memory is required during the tested operation. |

These are proposed appropriate evaluation dimensions, not claims that this guide has run such a study.

## 13 Poster section 8 Conclusion

### “Combines terminology learning, reviewed prescription capture, reminders, and source-grounded AI explanations in one workflow”

The system's contribution is connecting functions. For example, a reviewed scan can lead to source-backed understanding and then to saved medication organization. These are coordinated stages, not isolated technology logos.

### “Emphasizes confirmation, provenance, and privacy rather than autonomous diagnosis”

**Confirmation:** the user reviews recognized data.

**Provenance:** information about where a record/fact came from, such as provider, source identifier, version, retrieval time, and review status. Think of it as the information's origin/history label.

**Privacy:** controlled handling of personal information. Relevant implementation includes account boundaries, owner-scoped queries, secure credential storage, app-private images, and supported cleanup. Privacy is broader than hiding a name on the screen. Some auxiliary privacy settings were identified as incomplete in earlier audits, so do not claim comprehensive protection from every setting shown.

**Autonomous diagnosis:** software independently deciding which disease someone has. The app's educational explanations and saved reminders are a different function. The absence of diagnosis functionality does not mean no safety controls are needed.

### “Usable local FYP implementation with clear educational and practical value”

**FYP** means Final Year Project. **Local implementation** means you can run a development installation with the phone and reachable backend. It is not synonymous with a publicly deployed, clinically certified, production medical platform.

Educational value: easier access to medical-language learning. Practical value: reviewed record organization and reminder support. These are intended/demonstrated uses; a claim that they measurably improve patient health needs an appropriate study.

## 14 Poster section 9 Future Work

Future work names areas that need further development or evidence. It is normal for a project to have future work; explain each item concretely.

### 14.1 Broader validated datasets and stronger DRAP coverage

**Dataset:** a collection of organized examples/records. **Validated:** checked using stated rules and qualified review appropriate to the information. “More records” alone does not mean “better records.”

Future work can include more legitimate product records, local brands, reviewed terminology, source versions, duplicate handling, and difficult handwriting examples with permission and reference labels. DRAP coverage means supported Pakistan product data, not automatic international equivalence or universal availability.

### 14.2 Clinical evaluation and usability studies

**Clinical evaluation** examines relevant medical correctness/safety with appropriate expertise and study design. **Usability testing** asks whether intended users understand the interface and can complete tasks.

Example usability question: can a patient find an uncertain strength and correct it without help? Example evaluation question: do the explanations preserve the supported meaning of source facts?

Automated tests can check software behavior. They do not replace expert evaluation of medical output or research involving real users. This poster does not provide clinical trial results.

### 14.3 Physical-device and iOS verifications

The app being written in Flutter is not proof every platform operation works. Camera lifecycle, photo formats, microphone/notification permissions, Face ID, background alerts, signing/trust, and home-screen launch require device-specific checks.

Some release installation work has been done in this project. The future-work point still makes sense as a need for broader/repeated device coverage, rather than implying no iPhone build exists.

### 14.4 Improved provider integrations and interaction support

A **provider integration** is the adapter connecting the app to another service/source. Improvement can mean broader coverage, better failure handling, versioning, correct identity matching, or reduced latency.

In this context, **interaction support** means checking possible drug-drug interactions. That is a separate capability requiring suitable, validated data and clinical interpretation. The code currently has `NotConfiguredInteractionProvider`. Do not claim existing general medicine explanations perform a full interaction check.

### 14.5 Production deployment and extended FHIR or hospital integration

**Production deployment:** running a service for real users with suitable hosting, HTTPS, secret handling, monitoring, backups, updates, recovery, access control, and operational support. A Docker development setup is a useful foundation, not proof all production requirements are fulfilled.

**FHIR** expands to **Fast Healthcare Interoperability Resources**, pronounced like “fire.” It is an HL7 healthcare-information exchange standard. **Interoperability** means different systems can exchange information with agreed meaning and structure. [HL7 FHIR overview](https://www.hl7.org/fhir/R4/overview.html).

Think of two organizations agreeing on a form: which fields represent a medication, who the information concerns, and what each code means. FHIR supplies resource structures and exchange conventions; it is not an AI model or your database engine.

Your code has a draft mapping adapter. That is not a live hospital connection or demonstrated standards conformance. A patient-created reminder must not become a clinician-issued order. Extending integration would require an explicit FHIR version/profile, resource validation, consent, authentication, and a hospital partner/system.

## 15 Footer slogan and visual symbols

“Clearer Information, Healthier Community” communicates the project's motivation. It does not prove a measured improvement in community health.

“Understand • Manage • Remember • Your Health” connects to terminology/explanations, medication organization, and reminders.

The book, camera/OCR frame, pill, brain, calendar/check, and download/cloud symbols summarize learning, capture, medicine information, AI, reminders/history, and stored/offline behavior. A cloud/download icon does not by itself tell you whether a specific operation is offline; code and data flow decide that.

The leaf shapes, crosses, heart/ECG motif, colors, and human figures give a healthcare/community visual theme. The phone image is an interface illustration. These symbols are not additional implemented medical devices, vital-sign sensors, or real-time ECG analysis.

## 16 Where the poster ideas connect to code

| Poster idea | Useful real source location |
| --- | --- |
| Flutter root app | [main.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/main.dart), [app.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/app/app.dart). |
| Terminology search | [resolve_medical_term.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/features/terminology/application/resolve_medical_term.dart). |
| Learning records | [local_learning_repository.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/features/learning/data/local_learning_repository.dart). |
| Normal scan entry | [prescription_processing_screen.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/features/prescription/presentation/prescription_processing_screen.dart). |
| Scan orchestration | [prescription_workflow_controller.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/features/prescription/application/prescription_workflow_controller.dart). |
| Local OCR bridge | [on_device_ocr_provider.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/features/prescription/data/on_device_ocr_provider.dart). |
| Native Android/iOS readers | [MainActivity.kt](/Users/mahdiahrari/Developer/meddex/apps/mobile/android/app/src/main/kotlin/com/mediexplain/mediexplain/MainActivity.kt), [AppDelegate.swift](/Users/mahdiahrari/Developer/meddex/apps/mobile/ios/Runner/AppDelegate.swift). |
| Image transcription | [gemini_handwriting.py](/Users/mahdiahrari/Developer/meddex/services/api/app/services/gemini_handwriting.py). |
| Structured parsing | [prescription_structuring.py](/Users/mahdiahrari/Developer/meddex/services/api/app/services/prescription_structuring.py). |
| Review and confirmation | [prescription_review_screen.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/features/prescription/presentation/prescription_review_screen.dart). |
| Whole-list explanations | [api_medicine_batch_overview.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/features/prescription/data/api_medicine_batch_overview.dart), [medicine_batch_overview.py](/Users/mahdiahrari/Developer/meddex/services/api/app/services/medicine_batch_overview.py). |
| Sources and identity | [medication.py](/Users/mahdiahrari/Developer/meddex/services/api/app/providers/medication.py), [medicine_name_resolution.py](/Users/mahdiahrari/Developer/meddex/services/api/app/services/medicine_name_resolution.py). |
| Grounded generation checks | [medical_rag.py](/Users/mahdiahrari/Developer/meddex/services/api/app/services/medical_rag.py). |
| Provider routing/models | [cloud_fallback.py](/Users/mahdiahrari/Developer/meddex/services/api/app/providers/cloud_fallback.py), [config.py](/Users/mahdiahrari/Developer/meddex/services/api/app/core/config.py). |
| Reminder calculations | [schedule_engine.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/features/medications/application/schedule_engine.dart). |
| Alerts and dose actions | [medication_reminder_service.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/features/medications/application/medication_reminder_service.dart). |
| Local persistence | [app_database.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/core/database/app_database.dart). |
| Upload outbox | [sync_coordinator.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/core/sync/sync_coordinator.dart). |
| Admin permissions/governance | [dependencies.py](/Users/mahdiahrari/Developer/meddex/services/api/app/api/dependencies.py), [governance.py](/Users/mahdiahrari/Developer/meddex/services/api/app/services/governance.py). |
| Docker setup | [docker-compose.yml](/Users/mahdiahrari/Developer/meddex/docker-compose.yml). |
| Draft FHIR mapping | [medication_fhir_adapter.dart](/Users/mahdiahrari/Developer/meddex/apps/mobile/lib/features/medications/domain/medication_fhir_adapter.dart). |

## 17 Questions an examiner can ask

### What does offline-first mean

“Many everyday operations use local data first, so existing content and records remain usable without a new server call. Cloud scanning and new online AI requests still need connectivity.”

### Why is this called medical literacy

“It helps users understand medical language and medicine information. It is about understanding and organization, rather than independently diagnosing disease.”

### What is the difference between OCR and AI explanation

“OCR recognizes writing from an image. Explanation turns supported information into understandable wording. Recognized text alone is not proof of a medicine's purpose.”

### What is structured parsing

“It separates recognized content into named fields such as medicine name, strength, form, and instructions instead of keeping one unorganized paragraph.”

### What if OCR is wrong

“The user can check and edit recognized information. Uncertain or unsupported details should not silently become confirmed instructions.”

### Why review before explanation

“A fluent explanation of the wrong medicine would still be wrong. The workflow first asks the user to review the recognized list, then resolves evidence for the confirmed entries.”

### Does user confirmation guarantee correctness

“No. It records user review. It is not independent professional verification or a guarantee that the identity/dose is right.”

### What is source-grounded AI

“The backend retrieves relevant reference facts, gives them to the model, checks supported output and citations, and exposes sources. The model is not treated as the medical authority.”

### What is a citation versus provenance

“A citation points to supporting material. Provenance is broader metadata about where information came from, its version, retrieval, and review history.”

### Why not ask a chatbot directly

“The application adds a reviewed prescription workflow, identity resolution, reference retrieval, constrained output, visible sources, local persistence, and reminders. A free-form chatbot reply alone does not supply those guarantees or workflows.”

### Did you train your own model

“No. The project integrates pretrained readers and language models. The implementation work is in data flow, provider adapters, prompts, validation, references, privacy, UI, persistence, and testing.”

### Why does the poster show Qwen3 and Qwen3 8B

“Qwen3 is the family and 8B is a particular size/tag from an earlier local setup. The current code configures a smaller 1.7B text fallback, with Gemini/Groq cloud routing.”

### Is 8B the amount of RAM

“No. It is a parameter-count label. RAM depends on representation, quantization, context, runtime overhead, and other programs.”

### Is Qwen running on the iPhone

“The configured local Ollama fallback runs on the Mac. The phone uses the backend. Phone-local OCR is a separate capability.”

### Does ML Kit work on the current iPhone OCR path

“The current native iOS bridge uses Apple Vision. Android uses ML Kit. The normal prescription image flow currently chooses cloud reading, so the poster's ML Kit box does not describe every current execution path.”

### What do the graph scores measure

“They show an illustrative suitability comparison. The poster does not document an experimental metric or scoring method, so I would not call them accuracy percentages.”

### Why is Qwen's grounding score high

“The intended comparison is a language model inside a source-grounded pipeline versus OCR alone. Grounding comes from retrieval and application checks, not automatically from Qwen.”

### Why are ML Kit and Qwen both useful

“They solve different problems: recognizing image text and generating text from context. They are complementary components, not direct substitutes.”

### Why do you need RxNorm if AI knows drug names

“Model familiarity is not verified identity. RxNorm provides standardized terminology/identifiers useful for supported concept resolution.”

### What is the difference between RxNorm and DailyMed

“RxNorm primarily helps normalize medicine concepts and names. DailyMed provides labeling information. Their roles complement each other.”

### What does DRAP contribute

“Controlled, reviewed imports can support Pakistan product identities and registration-related information. Imports need legitimate provenance and cannot be assumed correct merely because a CSV parses.”

### Can a local product automatically use a US label

“No. Ingredient, strength, form, product/jurisdiction evidence, and variant differences matter. A shared brand/generic name alone is insufficient.”

### Are explanations sent one medicine at a time

“The current prescription flow sends the complete confirmed list to the batch endpoint. Evidence lookup may involve multiple source requests, but explanation generation is requested as a batch.”

### What happens if a reference or AI provider is unavailable

“The app can preserve work and show retry/unavailable/correction states. Supported generation failures can use configured alternatives or available source information. It must not invent missing medical evidence.”

### What happens after Taken or Skipped

“A dated user event is stored for the corresponding medication/dose. History and summaries read those records.”

### Does a reminder mean the app prescribed a time

“No. Reminders organize the user's reviewed schedule. The application should not infer missing clinical instructions as confirmed.”

### Why two databases

“SQLite supports local phone use. PostgreSQL supports shared server persistence. They run in different places and serve different roles.”

### How does synchronization work

“Supported changes create outbox operations. The app sends eligible operations when authenticated, allowed, and connected; failed operations can retry. That is not a claim of universal two-way merging.”

### Why use Flutter

“It provides shared Dart UI/feature code across mobile platforms. Native permissions and device integrations still require platform-specific work and tests.”

### What does FastAPI do

“It receives HTTP requests at defined endpoints and connects validation/dependencies to Python business services. Uvicorn runs the ASGI application.”

### What does Docker do

“It packages and runs backend services in reproducible containers. Compose connects the services and persistent storage.”

### Is the admin portal complete

“The backend admin APIs and governance exist. The web frontend source is absent from this checkout, so I cannot claim an included verified admin website.”

### Does the OpenAI logo prove you use ChatGPT directly

“No. We need to inspect the configured endpoint. This code supports an OpenAI-compatible interface and currently includes a Groq model with an OpenAI identifier.”

### How do you protect personal information

“The implementation includes account-specific local data, server ownership checks, secure credential storage, private image handling, and supported deletion. These controls have specific limits; a privacy claim needs actual enforcement and verification.”

### Why is clinical evaluation future work if tests pass

“Software tests check defined behavior. Medical correctness and patient usability need separate expert evaluation and suitable studies.”

### What is FHIR and is hospital integration live

“FHIR is a healthcare data-exchange standard. The project has draft mapping code, but that is not a live hospital integration or validated conformance.”

### What is the main contribution

“The integrated workflow: local learning and records, reviewed prescription capture, source-backed understanding, and personal medication organization, with explicit uncertainty and evidence handling.”

### What are the main limitations

“Difficult handwriting, incomplete reference coverage, provider/network limits, the absent admin frontend, some incomplete auxiliary features, and the need for broader clinical/usability/device evaluation.”

## 18 A two-minute walk through the poster

> “MediExplain helps patients understand medical language and organize reviewed medicine information. The problem is that terminology can be difficult, prescription details can be scattered, and OCR or AI results can be wrong if accepted without review.
>
> The application combines six modules: terminology and learning, prescription reading and review, medicine information, explanations with citations, reminders/history, and local data. A user can search terms directly or capture a prescription. The recognized writing is organized into medicine fields, then the user checks and confirms it. The backend resolves supported medicine identities and retrieves reference facts. Optional AI simplifies those facts, with output checks and visible citations. Reviewed records can be saved, and the user can configure reminders and record dose actions.
>
> Flutter and Dart build the mobile application. Python and FastAPI provide the backend. SQLite supports phone-local storage and PostgreSQL supports server records. Docker manages local backend services. The poster shows an earlier ML Kit and Qwen3 8B arrangement; the current app also uses cloud reading with Gemini/Groq and a smaller local Qwen3 1.7B text fallback. The admin frontend is not included in this checkout.
>
> The graph is an illustrative comparison of OCR and language-generation roles, not an accuracy benchmark. The project emphasizes understandable information, review, provenance, and privacy. Future work includes broader validated content, clinical/usability studies, device testing, interaction data, and production/hospital integration.”

## 19 What to revise first

1. Explain frontend, backend, API, and the two databases.
2. Learn the title's five ideas: offline-first, medical literacy, medication support, platform, and source-grounded AI.
3. Trace every workflow box in order and say what goes in and comes out.
4. Learn the difference between OCR, parsing, review, medicine resolution, and explanation.
5. Understand the technology logos and the current-versus-poster differences.
6. Memorize the honest graph answer and what 8B actually means.
7. Explain citations, provenance, privacy, and why the app does not diagnose.
8. Practice future-work answers and the two-minute walkthrough aloud.

If you cannot remember a library name, explain its job first. A clear understanding of the information flow is more useful than memorizing a list of logos.

## 20 Evidence and scope of this explanation

This guide is based on visual inspection of the supplied poster, current source files, and the linked official definitions for external technologies/reference resources. Source-code defaults are not a fresh check of runtime environment overrides. No app settings, records, keys, models, or the original poster were changed for this task. No new full regression, clinical study, or live model benchmark was performed.

The 1–5 graph values are transcribed as shown. Their experimental provenance remains unestablished in the inspected project. Historical documentation sometimes describes older providers or an admin frontend not present here; current source and actual demonstrated behavior should guide viva answers.
