# Agent Catalog

One page per agent in the ai-agent plugin: what each agent knows, how to launch it, what it
does when it runs, and where its authority stops. The pipeline the agents form:

```
/onboard-project  ->  /gap-analysis   ->  [/research-ticket]  ->  /create-spec  ->  /implement            ->  /hipaa-check
   doc-analyst         gap-analyst          jira-researcher        spec-writer      backend-springboot        hipaa-compliance
   (repeatable)        (stories arrive)     (optional)                               + frontend-react
```

`/research-ticket` is optional — `/create-spec` performs its own inline lightweight research
when no research file exists. Two approval gates are always mandatory: the spec approval gate
(the developer approves the tech-spec before `/implement` runs) and the plan gate (inside
`/implement`, before any code is written). `/implement-batch` runs the same implement stage for
several APPROVED tickets at once — each in its own `.worktrees/<KEY>` git worktree on its own
`feature/<KEY>` branch, launched in parallel under the same agents and gates, frontier-only
(blocked or file-overlapping tickets defer to the next run) and capped at 5 tickets / 3 agents
in flight.

The suite ships as three plugins from one marketplace: `ai-agent` (core) carries every agent
below except the two implementers, which ship in `ai-agent-backend` and `ai-agent-frontend` so
a repo loads only its own stack. Agent names are globally unique and launched by bare name.
Every `docs/` path in this catalog resolves under the **context root** (shared-standards
Context Root rule): the repo's own `docs/` by default, or the sibling context repo named by
`.claude/ai-agent.json` in the multi-repo topology.

| Agent | Plugin | Launched by | Role in one line |
|---|---|---|---|
| `doc-analyst` | ai-agent | `/onboard-project` | Distills the SRS in `docs/input-specs/` into `PROJECT_BRIEF.md` and scaffolds `docs/decisions.md` |
| `gap-analyst` | ai-agent | `/gap-analysis` | Compares the module-wise user-story workbooks against the brief into the regenerated `GAP_ANALYSIS.md` gap report |
| `jira-researcher` | ai-agent | `/research-ticket` | Excavates a Jira ticket read-only into `docs/tickets/<KEY>/research.md` |
| `spec-writer` | ai-agent | `/create-spec` | Turns ticket plus research into the locked-template tech spec, ending at the spec approval gate |
| `frontend-react` | ai-agent-frontend | `/implement`, `/implement-batch` | Implements the frontend (React/TypeScript) half of an approved spec |
| `backend-springboot` | ai-agent-backend | `/implement`, `/implement-batch` | Implements the backend (Java/Spring Boot) half of an approved spec, backend first |
| `hipaa-compliance` | ai-agent | `/hipaa-check` | Read-only PHI and audit-coverage review; its entire output is its report |
| `agent-auditor` | ai-agent | `/agent-audit` | Grades pipeline process (event log) + artifact conformance (templates) into a per-ticket scorecard and a trend row |

---

## doc-analyst

### What it knows

- Skills: `shared-standards` (the binding contract for every agent) and `hipaa` (the
  18-identifier table that grounds the Compliance Profile).
- Templates: the core plugin's `templates/project-brief.md` (the locked 11-section output
  contract) and `templates/decisions.md` (the decision-log scaffold it copies verbatim).
- Domain expertise: requirements analysis — distilling hundred-page SRS documents into the
  operational brief every downstream agent reads instead of the originals, with every claim
  attributed to its source document and section.

### How to invoke it

- Command: `/onboard-project [docs-dir]` (documents directory defaults to `docs/input-specs/`).
- Natural-language dispatch, from the agent's own examples: "We just dropped the SRS and the
  interface control document into docs/input-specs/. Set this project up for the AI pipeline";
  "Product shipped a major revision of the requirements spec last sprint, so the project brief
  is stale now"; "We finally confirmed which module implements the authorization entity — the
  brief still says not yet located" (the lightweight Column-Update Mode).

### What it will do

1. Hygiene sweep (command-level, before the agent launches; skipped in Column-Update Mode):
   standalone user-level agents in `~/.claude/agents/` are inventoried and offered for
   disabling — approved ones are moved, never deleted, to `~/.claude/agents-disabled/`. If any
   were moved, the run stops and asks for a fresh session plus a rerun: already-loaded
   definitions only unload when a new session starts. Plugin agents and the repo's own
   `.claude/agents/` are never touched.
2. Preflight: verifies the documents directory exists and inventories every file, classifying
   each as readable or unreadable — a missing or empty directory is a full stop with an
   actionable message, and skipped files are always reported with a conversion request.
3. Reads every readable document completely — no skimming, no sampling — collecting glossary
   terms, entities, business rules, compliance data categories, and integrations with sources.
   Meeting minutes are read with their dates — when dated minutes and the SRS disagree, the
   latest dated source wins, with both cited — and Figma links are followed read-only via the
   user's Figma connector (or listed as inaccessible with a frame-export request).
4. Distills the 11 locked sections of `PROJECT_BRIEF.md`; any ambiguous data category is
   fail-closed as "PHI (presumed — unconfirmed)" with an open question, never guessed. Every
   Section 11 module is written `Status: DRAFT` (only `/gap-analysis` certifies FINAL), and
   recorded resolutions in `docs/decisions.md` are honored in how conflicting or gapped
   requirements are stated — cited by ID, never treated as a requirement source.
5. Scaffolds `docs/decisions.md` verbatim from the plugin template only if it is absent; an
   existing decision log is never touched.
6. Writes `PROJECT_BRIEF.md` and, in the same action, its change manifest
   `docs/output-specs/.brief-state.json` — directly on first onboarding; on a targeted update
   (only changed/new documents re-read, only affected sections and modules recomposed,
   untouched modules byte-identical), a full regeneration, or a Column-Update it stops at the
   overwrite gate and returns a diff gate report, writing only when relaunched with the
   developer's approval.
7. Reports coverage, counts, the Compliance Profile summary with an explicit verification
   request, at most 2 open questions, and next steps.

### Scope guardrail

Writes exactly three files — `docs/output-specs/PROJECT_BRIEF.md`, its manifest
`docs/output-specs/.brief-state.json` (always together with a brief write), and
`docs/decisions.md` only when absent — and nothing else. It never edits, moves, or deletes
anything in the documents directory, never invents a domain fact the sources do not contain,
and never overwrites an existing brief without the diff-and-approval overwrite gate. It never
runs git; the developer commits.

### Provenance

Authored for the ai-agent plugin v1.0.0, 2026-07-21.

---

## jira-researcher

### What it knows

- Skills: `shared-standards`, `hipaa` (Compliance Notes and the no-PHI-values rule), and
  `audit-logging` when present (audit-event assessment in Compliance Notes).
- Templates: the core plugin's `templates/research.md` (the locked output contract).
- Domain expertise: requirements excavation — where the real requirement hides in comment #7
  while the description says what the first draft said, where a mockup contradicts the prose,
  where a Sub-task is unintelligible without its parent.

### How to invoke it

- Command: `/research-ticket <TICKET-KEY>`. Optional — run it when the ticket deserves full
  excavation; `/create-spec` handles simple tickets with its own inline research.
- Natural-language dispatch, from the agent's own examples: "PLAT-421 has a forty-comment
  thread and three mockups. Dig through all of it before we write the spec"; "BILL-88 is a
  sub-task and honestly I can't tell what the parent actually requires of it"; "The research
  file for MEM-1204 predates the PM's latest comments, so it's stale. Refresh it."

### What it will do

1. Preflight: validates the ticket key and verifies the Atlassian MCP connector by fetching
   the ticket — an unavailable connector or an unresolvable key is a full stop, never worked
   around. An existing research file routes the run through the overwrite gate
   (diff, refresh-or-keep options).
2. Excavates the ticket completely: description, all comments chronologically (the latest
   comment overrides earlier ones), linked issues one hop deep by link type, the changelog,
   metadata verbatim, every image attachment read visually for layout intent, and every Figma
   link followed read-only via the user's Figma connector (or listed as inaccessible with a
   frame-export request); on a Sub-task the parent issue is required reading.
3. Scans the codebase for related files and reusable prior implementations; stack facts come
   from build files only.
4. Cross-checks the ticket against `PROJECT_BRIEF.md` entities and `docs/decisions.md`
   constraints; Compliance Notes fail closed when the Compliance Profile is missing or
   incomplete.
5. Writes `docs/tickets/<KEY>/research.md` against the locked template (through the overwrite
   gate when a file existed) and reports the two-sentence requirement, AC attributions,
   conflicts (matrix-resolved or OPEN), open questions, and inaccessible sources.

### Scope guardrail

Jira is strictly read-only through the user's Atlassian MCP connector — no comments,
transitions, field edits, or issue creation, and never a REST or stored-credential fallback.
It captures requirements but never designs solutions and never writes code. It writes exactly
one file, the research file; it never appends `docs/decisions.md` and never runs git.

### Provenance

Authored for the ai-agent plugin v1.0.0, 2026-07-21.

---

## spec-writer

### What it knows

- Skills: `shared-standards`, `hipaa` (PHI marking in the API contract, Section 8 compliance
  content), and `audit-logging` when present (typing Section 8 audit events).
- Templates: the core plugin's `templates/tech-spec.md` (the locked 13-section output contract).
- Domain expertise: contract design — API contracts, data-model changes, and integration
  designs precise enough that implementers consume Section 5 verbatim with no inference.

### How to invoke it

- Command: `/create-spec <TICKET-KEY>`. Uses `docs/tickets/<KEY>/research.md` when present;
  otherwise performs inline lightweight research (live read-only Jira fetch — image attachments
  and Figma links included — plus repo scan).
- Natural-language dispatch, from the agent's own examples: "Research for PLAT-421 is done —
  turn it into a tech spec so we can start building"; "I need a spec for BILL-88. We never ran
  the research command on that one"; "The API shape for MEM-1204 changed in the latest Jira
  comments, so the current spec is wrong."

### What it will do

1. Preflight: builds on the research file when one exists; otherwise runs inline lightweight
   research — an unavailable Atlassian MCP in inline mode is a full stop, and complexity
   signals (contentious threads, attachment piles, Sub-tasks) fire the complexity pause gate
   recommending `/research-ticket` first. An existing spec routes through the overwrite gate.
2. Maps every acceptance criterion verbatim to EXISTING, FRONTEND-ONLY, BACKEND-REQUIRED, or
   CROSS-STACK — proving reuse does not exist before classifying anything as new work.
3. Designs the approach after reading `docs/decisions.md`; a design that contradicts a prior
   entry fires the conflict gate, and new architectural decisions are drafted in its report
   for the launching command to append only after developer approval.
4. Fills the 13-section locked template; API contract elements are never guessed — anything
   undiscoverable goes to Section 12 (open questions) or Section 7 (cross-stack dependencies),
   and PHI-bearing fields carry the PHI marker (fail-closed when the profile is unconfirmed).
5. Self-reviews against a machine-checkable list, writes the spec with Approval Status exactly
   DRAFT, and ends at the spec approval gate: the developer reviews, resolves open questions,
   and flips the Section 13 line to `APPROVED by {name} on {YYYY-MM-DD}` — that exact form.

### Scope guardrail

Designs only; never implements — no source files, migrations, or tests. Writes exactly one
file, the tech spec (the sole exception: prepending the SUPERSEDED banner to a different
ticket's spec in a developer-directed cross-ticket supersession). It never writes APPROVED —
only the developer flips that line — never writes `docs/decisions.md`, reads Jira strictly
read-only, and never runs git.

### Provenance

Authored for the ai-agent plugin v1.0.0, 2026-07-21.

---

## frontend-react

### What it knows

- Skills: `shared-standards`, `hipaa` (client-side PHI surfaces: console output, browser
  storage, URLs and route params, analytics, error reporting, fixtures), and `react` (stack
  discovery, state ownership, Section 5 contract fidelity, component quality, TypeScript,
  accessibility, testing).
- Inputs it consumes: the approved tech spec at `docs/tickets/<KEY>/tech-spec.md` (Section 5
  verbatim), `docs/tickets/<KEY>/research.md` for visually-recorded UI intent,
  `PROJECT_BRIEF.md`, and `docs/decisions.md`.
- Domain expertise: React/TypeScript implementation grounded in the consuming repo's own
  conventions, discovered from `package.json` and existing source at task time.

### How to invoke it

- Command: `/implement <TICKET-KEY>` — launched for FRONTEND-ONLY acceptance criteria and the
  frontend half of CROSS-STACK work once the blocking Section 7 rows are RESOLVED (backend
  implements first). `/implement-batch` launches it the same way, once per ticket, each run
  pinned to that ticket's `.worktrees/<KEY>` source root.
- Natural-language dispatch, from the agent's own examples: "PLAT-421's spec is approved and
  every AC is FRONTEND-ONLY — build it"; "The backend endpoints for MEM-88 are merged and
  reviewed, and the Section 7 rows are marked RESOLVED — do the React half now." Asking it to
  build from a DRAFT spec produces a refusal, by design.

### What it will do

1. Preflight: re-reads the spec from disk — a SUPERSEDED banner, any Approval Status other
   than the exact `APPROVED by {name} on {YYYY-MM-DD}` line, or leftover Section 12 questions
   is a full stop; UNRESOLVED Section 7 rows blocking frontend work fire the cross-stack hard
   gate (no mocks, stubs, or workarounds — ever).
2. Absorbs the spec: Section 5 consumed verbatim; UI intent comes from the ticket's
   visually-read attachments and Figma frames recorded in research.md (visual design sources
   win the UI, the spec keeps the payload contract).
3. Discovers conventions from `package.json` and the existing source — data-fetching library,
   state store, form library, router, cache-key scheme, breakpoints, test runner — nothing
   pinned, nothing imported from memory.
4. Stops at the plan gate — Files to Create / Files to Modify / Existing Code Reused / Risks —
   on every run, before any code is written.
5. Implements the approved plan exactly; mid-run gaps fire the contract-gap gate,
   new-dependency gate, or a re-fired plan gate on drift — never a guess, never a silent add.
   Writes behavior-level tests with no PHI in fixtures and runs the project's own scripts.
6. Self-reviews and reports: the AC coverage checklist, verbatim test output, compliance
   findings ending with the exact `Findings: N VIOLATION, N RISK, N BEST-PRACTICE` line, draft
   decision entries, and review pointers.

### Scope guardrail

Writes only inside the frontend app's source and test tree — never backend code, and shared
cross-stack files only through explicitly flagged, approved plan rows. It never edits the tech
spec (including Section 7 statuses), never writes APPROVED or `docs/decisions.md`, never
touches Jira, never adds a dependency without the gate, never weakens a test to make it pass,
and never commits or pushes.

### Provenance

Authored for the ai-agent plugin v1.0.0, 2026-07-21.

---

## backend-springboot

### What it knows

- Skills: `shared-standards`, `hipaa` (Never-Log List, Safe Logging for Java/SLF4J,
  framework-error-message hygiene, Minimum Necessary Checklist, API Surface Rules, the
  `// HIPAA:` comment rule), `spring-boot`
  (Discovery Preamble, SOLID/KISS/YAGNI/DRY as checkable review rules, layering, contract
  fidelity, API contract safety, configuration binding, migrations, upgrade verification,
  performance rules, testing standards), and `audit-logging` when the spec's Section 8
  lists PHI touchpoints or audit events (Event Taxonomy, 7-Component Spring Pattern,
  Anti-Pattern Review Checklist).
- Inputs it consumes: the approved tech spec (Section 5 verbatim), `PROJECT_BRIEF.md`
  (Module Map, NEVER-EDIT-LIGHTLY list, Compliance Profile), and `docs/decisions.md`.
- Domain expertise: Java/Spring Boot implementation — entities, migrations, endpoints,
  services, authorization, and audit events — with every stack fact discovered from the
  consuming repo's build files and existing code at task time.

### How to invoke it

- Command: `/implement <TICKET-KEY>` — launched first for BACKEND-REQUIRED acceptance criteria
  and the backend half of CROSS-STACK work. `/implement-batch` launches it the same way, once
  per ticket, each run pinned to that ticket's `.worktrees/<KEY>` source root.
- Natural-language dispatch, from the agent's own examples: "The tech spec for PLAT-421 is
  approved — implement the backend portion"; "Build the new referral endpoint and its
  migration from MEM-1204's spec"; "BILL-88 is cross-stack — get the backend done first so the
  frontend team can start."

### What it will do

1. Preflight: verifies on disk the exact `APPROVED by {name} on {YYYY-MM-DD}` line and that
   Section 12 reads NONE — anything else is a full stop; a SUPERSEDED banner is a stop; and
   UNRESOLVED Section 7 rows blocking backend work fire the cross-stack hard gate.
2. Absorbs Section 5 as a verbatim contract; a missing or ambiguous element fires the
   contract-gap gate — the question-budget "defensible default" never applies to a contract
   element.
3. Runs the spring-boot skill's Discovery Preamble against the repo: versions, module layout,
   error envelope and exception handler, migration tool, test strategy, and any existing audit
   seam — discovered, never assumed, never imported from memory.
4. Stops at the plan gate with the four-part plan (Files to Create / Files to Modify /
   Existing Code Reused / Risks) on every run; nothing is written before approval.
5. Implements the approved plan: data model first as append-only migrations, endpoints flowing
   through the repo's existing error envelope, authorization and audit events per Section 8
   (7-Component Spring Pattern), PHI discipline throughout; new dependencies and plan drift
   fire their gates.
6. Tests per Section 10 with the repo's real build and test commands, then reports the AC
   coverage checklist, verbatim results, compliance and technical findings under their own
   separate count lines (never merged), draft BE-NNN decision entries, and the cross-stack
   handoff naming the Section 7 rows its work satisfies.

### Scope guardrail

Backend only — it never modifies frontend files, and shared cross-stack files only through
explicitly flagged, approved plan rows. It never marks a Section 7 row RESOLVED (the developer
directs that through `/implement`), never edits the tech spec, `docs/decisions.md`,
`PROJECT_BRIEF.md`, or Jira, never edits an applied migration, never logs PHI, and never
commits or pushes.

### Provenance

Authored for the ai-agent plugin v1.0.0, 2026-07-21. Its Spring Boot audit-logging, error
envelope, and PHI-discipline patterns are adapted from real healthcare production
implementations, generalized so the agent discovers each consuming repo's own conventions at
runtime — nothing in the agent names an organization, project, or fixed directory layout.

---

## hipaa-compliance

### What it knows

- Skills: `shared-standards`, `hipaa` (the 18-identifier PHI table, Never-Log List, Safe
  Logging patterns, framework-error-message hygiene, Minimum Necessary Checklist, API Surface
  Rules, the 42 CFR Part 2 obligations when the Compliance Profile flags them, and the
  fail-closed rule), and `audit-logging` (the Event Taxonomy and the 13-anti-pattern review
  checklist).
- Inputs it consumes: the code or spec under review, and `PROJECT_BRIEF.md`'s Compliance
  Profile — which tells it what counts as PHI in this specific project. It fills no templates.
- Domain expertise: HIPAA compliance review — PHI leak detection across logs, error messages,
  URLs, payloads, and fixtures, plus audit-trail coverage assessment.

### How to invoke it

- Command: `/hipaa-check [path]` — a standalone compliance scan, usable at any time: before a
  PR, on a legacy module, or on a spec.
- Typical requests that dispatch to it: "Scan this diff for PHI leaks before I open the PR";
  "Run a compliance check on the billing module"; "Does this spec's error handling leak
  member data?"

### What it will do

1. Preflight: resolves the scan scope and reads `PROJECT_BRIEF.md`'s Compliance Profile. A
   missing or incomplete profile means fail-closed per the hipaa skill: ALL person-related
   data is treated as PHI, and the report says so up front.
2. Reviews the target read-only for PHI-leak findings against the hipaa skill's rules —
   logging, exception messages, URLs, API surfaces, queries and projections, test fixtures.
3. Separately assesses audit coverage against the audit-logging skill's 13-anti-pattern
   checklist — the two rule sets are never merged into one list.
4. Sanitizes every quoted snippet: any real-looking value is replaced with a placeholder
   before it enters the report — the report itself never contains PHI.
5. Returns its report as its entire output: PHI-leak findings ranked VIOLATION > RISK >
   BEST-PRACTICE with corrected code mandatory for every VIOLATION, ending with the exact
   `Findings: N VIOLATION, N RISK, N BEST-PRACTICE` line; then a separate audit-coverage
   section with its own count line. Corrected code appears inside the report for the developer
   (or a later `/implement` run) to apply — the agent applies nothing.

### Scope guardrail

The plugin's only genuinely read-only agent: it writes NO files and edits NO code — its entire
output is its report, and it never applies a fix. Because it writes nothing, it has no
overwrite or plan gates; its only stops are preflight failures and the conflict gate. It never
commits, and it never puts PHI in its own report.

### Provenance

Authored for the ai-agent plugin v1.0.0, 2026-07-21. Its review rules are adapted from real
healthcare implementations, stated generically — nothing in the agent names an organization or
assumes a specific project.

---

## agent-auditor

### What it knows

- Skills: `shared-standards` (the binding contract for every agent).
- Templates: the core plugin's `templates/research.md`, `templates/tech-spec.md`, and `templates/decisions.md` —
  the locked structures artifact conformance is graded against, with required-section lists
  derived from the template files at run time, never from memory.
- Data source: the observability event log `.claude/ai-agent-metrics/events.jsonl` (plus its
  `.old` rotation), written by the plugin's PostToolUse hook from v1.1.0 on — metadata-only
  records of skill invocations, agent spawns, standards reads, artifact writes, and the safety
  hooks' denials.

### How to invoke it

- Command: `/agent-audit <TICKET-KEY>`.
- Natural-language dispatch, from the agent's own examples: "PLAT-421 just shipped — did the
  agents actually follow the pipeline on it?"; "We want to track over time whether the
  plugin's agents keep reading the hipaa skill."

### What it will do

1. Preflight: verifies `docs/tickets/<KEY>/` exists (a ticket no pipeline stage has touched is
   a full stop); locates the event log, falling back to artifact-only mode when it is absent —
   process checks become NO-DATA, never fabricated.
2. Gathers evidence: identifies the sessions that worked this ticket from the event log, and
   collects each one's agent spawns, skill loads, knowledge reads, artifact writes, and hook
   denials; maps sessions to pipeline stages by what they wrote.
3. Grades process checks P1–P9 (right agent per stage, right skills loaded, PROJECT_BRIEF read,
   hipaa skill on PHI-relevant work, zero denials) — every grade cites its log-line evidence or
   is NO-DATA with the reason.
4. Grades artifact conformance A1–A5 against the locked templates — structure and completeness
   only, never content quality (judging spec quality is the spec approval gate's job).
5. Writes exactly two files: the regenerated scorecard `docs/tickets/<KEY>/audit.md` and one
   appended row in `docs/agent-metrics.md` (created with its header when absent) — the
   over-time trend view.
6. Reports the counts line, every FAIL/WARN with evidence, denials, caveats, and both paths.

### Scope guardrail

Report-only in the strongest sense: a FAIL blocks nothing, gates nothing, and the agent fixes
nothing — it never edits a pipeline artifact, never touches code, and never runs git (not even
read-only). It writes exactly two files (the scorecard, regenerated per run, and the
append-only metrics row) and quotes event-log metadata without re-interpreting it; values that
pattern-match never-write shapes are reported by pattern name, never by value. It is not a code
reviewer and not a compliance reviewer — process and structure only.

### Provenance

Authored for the ai-agent plugin v1.1.0, 2026-08-06, as Phase 2 of the observability
initiative (Phase 1: the metadata-only event-logging hook).

---

## gap-analyst

### What it knows

- Skills: `shared-standards` (the binding contract for every agent).
- Templates: the core plugin's `templates/gap-report.md` — the locked 6-section report it regenerates, with the
  four gap types (MISSING-STORY, UNSOURCED-STORY, CONFLICT, PARTIAL) and the module statuses
  (ALIGNED, GAPS, NO-STORIES, STORIES-ONLY).
- Tooling: the core plugin's `scripts/xlsx-extract.py` (python3 stdlib) — the only way it reads the `.xlsx`
  user-story workbooks; workbook contents are never guessed.
- Domain expertise: backlog-vs-specification reconciliation — mapping the developer's
  module-wise user stories onto the brief's Module Briefs (Section 11) through the Domain
  Glossary, and reporting drift in both directions with both sides cited.

### How to invoke it

- Command: `/gap-analysis` (no arguments — one run always compares all modules). Run it after
  `/onboard-project` writes or updates the brief and the story workbooks are in place, and
  again after each round of corrections until every module reads ALIGNED. The agent only
  compares and reports; the resolution pass, the `GAP-` decision appends, and the Section 11
  FINAL flips are the command's own main-session writes, each confirmed with the developer.
- Natural-language dispatch, from the agent's own examples: "We dropped the module-wise user
  stories spreadsheet into docs/input-specs/ — check them against the SRS and the minutes";
  "We fixed the auth stories after the last gap report — where do we stand now?"

### What it will do

1. Preflight: verifies the brief exists and carries Section 11 (a pre-1.1.0 brief must be
   regenerated first) and that at least one `.xlsx` workbook is in `docs/input-specs/` —
   either missing is a full stop pointing at the prerequisite, never an improvised comparison.
2. Reads the brief completely (side A); extracts every workbook sheet via xlsx-extract.py
   (side B), discovering column layout from headers and resolving each story's module by
   Module column, then sheet name, then file name.
3. Maps story modules to brief modules — exact match, then Domain Glossary synonyms; anything
   unmappable is reported UNMAPPED with a disposition request, never forced into a bucket.
4. Compares each mapped module in both directions: brief requirements no story covers
   (MISSING-STORY / PARTIAL), stories nothing in the brief grounds (UNSOURCED-STORY), and
   contradictions quoted from both sides (CONFLICT) — direction of fix is always the
   developer's call.
5. Regenerates `docs/output-specs/GAP_ANALYSIS.md` whole — one consolidated module-wise
   report — and reports in chat: verdict with delta against the previous run, the module
   status table verbatim, top gaps with citations, unmapped modules, and the iteration next
   step (the command's resolution pass follows; fix what the approved resolutions direct and
   rerun until every module reads ALIGNED and is certified FINAL).

### Scope guardrail

Report-only in the strongest sense: a gap blocks nothing, and the agent fixes nothing — it
never edits a story, the brief, a source document, or code, and never runs git. It writes
exactly one file (the gap report, regenerated by contract on every explicitly-triggered run).
The `GAP-` decision appends and Section 11 FINAL flips belong to the `/gap-analysis` command
in the main session — never to this agent. The brief is its comparison baseline, never its
target: a brief that looks wrong or stale becomes an open question pointing at
/onboard-project, not an improvised finding. No realistic personal-data values from stories or
documents ever appear in its output — categories only.

### Provenance

Authored for the ai-agent plugin v1.1.0, 2026-08-10, as Phase 3 of the gap-analysis
initiative (Phase 1: workspace scaffolding + the input/output-specs split; Phase 2: the
xlsx extraction tooling).

---

## v2 candidates

Two capabilities are explicitly out of scope for v1 and planned as v2 candidates, so scope
questions have an answer:

- **A general PR-review agent.** v1 review capability is compliance-focused
  (`hipaa-compliance` via `/hipaa-check`) plus each implementer's own self-review; a
  general-purpose pull-request reviewer is a v2 candidate.
- **Jira write-back.** Jira access is read-only with one exception shipped in 2.0.1: the
  approval-gated cross-stack handoff comment `/implement` posts (developer approves the exact
  text; posted via the developer's own connector). Broader write-back — transitioning status,
  linking issues, or any unattended write — remains a v2 candidate.
