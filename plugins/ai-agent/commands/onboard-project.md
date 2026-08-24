---
name: onboard-project
description: Onboard or update a project for the AI pipeline via the doc-analyst agent — read the documents in the documents directory (default docs/input-specs/), distill or incrementally update docs/output-specs/PROJECT_BRIEF.md, maintain its change manifest docs/output-specs/.brief-state.json, and scaffold docs/decisions.md if absent. Begins with a standalone-agent hygiene sweep — user-level agents in ~/.claude/agents/ are inventoried and, with the developer's approval, moved aside so stale definitions stop loading into every session. Repeatable — reruns detect changed, new, and deleted input documents via the manifest and offer a targeted update of the affected brief modules (their Status flips to DRAFT) or a full regeneration; every overwrite goes through the diff-and-approval gate. Where Implemented updates run in Column-Update Mode.
argument-hint: [docs-dir]
---

# /onboard-project

Thin orchestrator. This command validates inputs, runs preflight checks, launches the `doc-analyst`
agent, and presents its results. It NEVER reads the source documents, distills the brief, or writes
any part of `PROJECT_BRIEF.md`, `docs/output-specs/.brief-state.json`, or `docs/decisions.md`
inline — that is the agent's job, defined in `${CLAUDE_PLUGIN_ROOT}/agents/doc-analyst.md`. The
one thing this command does compute itself is change detection (step 4): listing and hashing the
input files, classifying them against the manifest, and confirming the update scope with the
developer — main-session work, because the confirmation is.

## Instructions

0. **Standalone-agent hygiene sweep.** Stale user-level agents load their definitions into every
   session on this machine and quietly consume context. Sweep them before onboarding starts. This
   step does NOT apply in Column-Update Mode — determine that first (step 3's criteria) and skip
   straight to step 1 if so. Scope is exact: only standalone agent files in `~/.claude/agents/`
   are candidates. Agents provided by installed plugins live in the plugin cache and are NEVER
   touched. Agent files in the consuming repo's `.claude/agents/` are team-committed: LIST them
   for awareness ("remove via a PR if stale") but NEVER move or modify them.

   a. **Inventory.** List `~/.claude/agents/*.md`. If the directory is missing or holds no `.md`
      files, print exactly "No standalone user-level agents found — proceeding." and continue to
      step 1. Otherwise, for each file read the frontmatter `name` and `description` (when
      unreadable, show the filename with "no description readable") and its last-modified date —
      an agent untouched for months is a staleness signal the developer should see.

   b. **Ask — never decide.** Present the inventory with AskUserQuestion: multi-select, one
      option per agent where SELECTING AN AGENT MEANS DISABLING IT, and "Keep all listed
      (Recommended)" as the first option. Phrase the question so the polarity is unmistakable:
      "Select agents to DISABLE (move out of ~/.claude/agents/)". Batch at most 4 agents per
      question and at most 4 questions per call; more than that means additional calls. If "Keep
      all listed" is selected alongside individual agents, keep-all wins. Never say "delete": the
      action is a reversible move.

   c. **Apply — move, never delete.** For each agent the developer selected: create
      `~/.claude/agents-disabled/` if absent, then move the file there. On a name collision in
      the destination, append a numeric suffix (`-1`, `-2`, ...) rather than overwriting. NEVER
      delete an agent file, and never touch a file the developer did not select.

   d. **Stop or proceed.** If nothing was moved (keep-all or empty selection), print one line —
      "Agent sweep complete — nothing disabled." — and continue to step 1. If one or more agents
      were moved, their definitions are already loaded into THIS session, so the savings only
      arrive in a fresh one. Print exactly this (substituting the count and names) and STOP — do
      not run any later step:

      > Moved {n} agent(s) to ~/.claude/agents-disabled/: {names}. To undo, move a file back into
      > ~/.claude/agents/. These definitions are still loaded in the current session — start a
      > NEW session and run /onboard-project again; the sweep will find nothing left to remove
      > and onboarding will proceed cleanly.

   On a re-run, agents the developer chose to keep are still present and will be listed again —
   "Keep all listed (Recommended)" makes that a single click. Do not invent state files or
   markers to remember prior answers.

1. **Parse the argument.** `$ARGUMENTS` is optional. Trim whitespace. If it is empty, the documents
   directory is `docs/input-specs/` (the shared-standards canonical path). Otherwise `$ARGUMENTS` is the
   documents directory, resolved like every `docs/` path per the shared-standards Context Root
   rule. Call the resolved directory `<DOCS-DIR>` below.

2. **Preflight.** Run every check. Each check either passes, informs, or STOPS with its message —
   never silently degrade, never improvise a fallback.

   Resolve the context root FIRST, per the shared-standards Context Root rule: read
   `.claude/ai-agent.json` at the repo root — when it carries a `contextRoot`, every `docs/`
   path in this command and the agent definition (including the default `<DOCS-DIR>`) resolves
   under that path; without a pointer they are this repo's own `docs/` tree, exactly as
   written. A pointer that does not resolve to a readable directory is a HARD STOP — print
   exactly this and go no further:

   > /onboard-project cannot start: this repo's .claude/ai-agent.json points at a context root
   > that does not resolve.
   > Pointer value: {contextRoot}
   > Fix the pointer, or clone the project-context repo as a sibling at that path, or delete
   > .claude/ai-agent.json to use this repo's own docs/ directory. Then rerun /onboard-project.

   a. **Documents directory check — does not apply in Column-Update Mode.** First determine
      whether the request is Column-Update Mode (step 3). If it is, SKIP this check: a Where
      Implemented update reads no documents — it requires only that `PROJECT_BRIEF.md` exists,
      and step 3's stop for a missing brief covers that. Otherwise `<DOCS-DIR>` must exist and
      contain at least one file — of any format; classifying files as readable or unreadable is
      the agent's Phase 0 job, so do not pre-filter. The one exception: the directory's own
      `README.md` is the plugin's scaffolding, never a project document — a directory holding
      nothing but that README counts as empty. If the directory is missing or empty, print
      exactly this — doc-analyst's own Phase 0 stop message, substituting the actual directory —
      and STOP:

      > Onboarding cannot start: <DOCS-DIR> does not exist or contains no documents. The plugin's
      > SessionStart hook normally creates docs/input-specs/ and docs/output-specs/ automatically —
      > if they are missing, create both folders manually. Then place the required inputs in
      > <DOCS-DIR>: the SRS, meeting minutes (MOMs), and design links or exported frames — and
      > rerun /onboard-project.

   b. **Existing-brief detection.** Check whether `docs/output-specs/PROJECT_BRIEF.md` exists.
      If it does, tell the developer now that update rules apply: step 4 will classify what
      changed and confirm the scope, and the agent will build the new brief in memory, stop
      without writing anything, and return a gate report containing the diff between the current
      brief and the proposed one; this command presents that report and relaunches the agent with
      the developer's decision.

   c. **Decision log detection.** Check whether `docs/decisions.md` exists. If it does, it will be
      left completely untouched — it is append-only and owned by the project. If it is absent, tell
      the developer the agent will copy the plugin's scaffold to `docs/decisions.md` verbatim as a
      direct write; that is scaffold creation, not a decision append, so no approval gate applies.

   d. **No Atlassian MCP requirement.** doc-analyst reads local documents only. Do NOT check for,
      wait on, or block on the Atlassian connector — onboarding runs entirely without it. Do NOT
      block on the Figma connector either: it is optional — when the documents carry Figma links
      and the connector is unavailable, the agent lists each link as an inaccessible source with a
      frame-export request; that is report content, never a preflight failure.

3. **Detect Column-Update Mode.** If the developer's request accompanying this command is ONLY a
   Where Implemented update to Section 3 of `PROJECT_BRIEF.md` — a claimed implementation location
   for an existing entity row, with no SRS change — say so and launch doc-analyst in its
   lightweight Column-Update Mode: no document re-read, verification of the claimed location by
   opening the named file, and delivery through the same overwrite gate with a diff confirming
   everything outside the Section 3 column is byte-identical. Column-Update Mode requires an
   existing `PROJECT_BRIEF.md`; if step 2b found none, print this and STOP:

   > Cannot update the Where Implemented column: docs/output-specs/PROJECT_BRIEF.md does not exist.
   > Run /onboard-project (full onboarding) first.

4. **Change detection and scope confirmation.** Skip this step entirely in Column-Update Mode
   (step 3). The command does all detection here, in the main session — doc-analyst never hashes
   input documents itself.

   a. **Inventory.** List the files in `<DOCS-DIR>`, excluding the scaffolding `README.md` and
      every `.xlsx` workbook (those are gap-analysis inputs, never brief sources — they are never
      manifest-tracked and never trigger brief updates).
   b. **Hash.** Compute sha256 per file: `shasum -a 256`, else `sha256sum`. If neither tool is on
      PATH, hashes are null: with no existing brief that is FULL ONBOARDING as normal; with an
      existing brief, force REGENERATION (reason: "hashing unavailable") — never an error.
   c. **Manifest read.** Read `docs/output-specs/.brief-state.json`. Treat it as ABSENT — never an
      error — when it is missing, not valid JSON, its `schemaVersion` is not 1, or its `docsDir`
      differs from `<DOCS-DIR>`. Then: no brief (step 2b) → mode is FULL ONBOARDING, skip d–g.
      Brief exists but manifest absent → mode is REGENERATION (reason: "manifest missing or
      unreadable — full re-read required to seed it"), skip d–g.
   d. **Brief integrity.** Compare the manifest's `briefSha256` against the actual hash of
      `docs/output-specs/PROJECT_BRIEF.md`. On mismatch, warn — "PROJECT_BRIEF.md differs from
      the last agent-written version — hand edits or an unrecorded write." — and ask
      (AskUserQuestion): **Full regeneration (Recommended)** — the canonical brief derives from
      sources and decisions; hand edits belong in those, and the gate diff will show what they
      lose / **Targeted update anyway** — hand edits outside the affected sections survive
      byte-identical; edits inside them surface in the gate diff / **Abort**.
   e. **Classify** every inventoried file against the manifest: in the manifest with an equal
      hash → **unchanged**; with a different hash → **changed**; on disk but not in the manifest
      → **new** — unless its hash equals a deleted entry's hash, then → **renamed** (a pure
      rename is not an input change: the agent updates citations and the manifest, and module
      Statuses do NOT flip); in the manifest but not on disk → **deleted**.
   f. **Degenerate cases.** Everything unchanged and the brief hash matches: print exactly — "No
      input changes detected since the last brief (manifest match). Nothing to update. To force a
      full rebuild, say so and rerun /onboard-project." — and STOP. No unchanged docs remain
      (every tracked document changed or was deleted): skip the scope question and proceed as
      REGENERATION (reason: "all input documents changed").
   g. **Confirm scope** (AskUserQuestion, one call): "{c} changed, {a} new, {d} deleted of {m}
      input documents. Affected brief modules: {deduplicated union of the manifest's `modules`
      arrays for the changed, renamed, and deleted files}." Options: **Targeted update
      (Recommended)** — re-read only the changed and new documents, recompose only the affected
      sections and modules, flip their Status to DRAFT / **Full regeneration** — re-read
      everything / **Abort**. When deletions exist, a second question in the same call:
      "Deleted: {names}." Options: **Treat as removed inputs (Recommended)** — recompose the
      affected modules without them, retire rules sourced solely to them / **Stop — I'll restore
      the files first**.

   The result is the mode for step 5: FULL ONBOARDING, TARGETED UPDATE, or REGENERATION.

5. **Report the mode before launching.** One short block, so the developer knows what is about to
   happen:

   - FULL ONBOARDING: "PROJECT_BRIEF.md does not exist — doc-analyst will read every document in
     <DOCS-DIR> completely and write the brief directly."
   - TARGETED UPDATE: "PROJECT_BRIEF.md and its manifest exist — {c} changed, {a} new, {d}
     deleted of {m} input documents. doc-analyst will re-read only those, recompose the affected
     sections and modules ({module list}), flip their Status to DRAFT, honor recorded resolutions
     in docs/decisions.md, and return a diff gate report. Every untouched module stays
     byte-identical — the diff will confirm it."
   - REGENERATION: "PROJECT_BRIEF.md exists — {reason: developer chose full regeneration |
     manifest missing or unreadable | all input documents changed | hashing unavailable}.
     doc-analyst will re-read <DOCS-DIR> completely, rebuild the brief in memory honoring
     recorded resolutions in docs/decisions.md, flip every module's Status to DRAFT, and return a
     diff gate report for your approval before anything is written."
   - COLUMN-UPDATE: "Where Implemented update only — doc-analyst will verify the claimed location
     and return a diff gate report; no documents are re-read."

   Include the step 2c decision-log note in this block.

6. **Launch the doc-analyst agent** via the Task/Agent mechanism with a prompt that states
   precisely:

   - the resolved context root (the agent resolves every `docs/` path in its definition under
     it — it never re-derives the pointer);
   - the documents directory `<DOCS-DIR>` (the agent uses it everywhere its definition says
     `docs/input-specs/` and names it in Sections 9 and 10 of the brief);
   - whether `docs/output-specs/PROJECT_BRIEF.md` already exists (Phase 4 overwrite gate
     applies if so);
   - whether `docs/decisions.md` already exists (scaffold copied verbatim only if absent; an
     existing file left untouched; when it exists the agent honors its recorded resolutions —
     Decision Log Protocol item 1);
   - the mode: full onboarding, targeted update, regeneration, or Column-Update Mode (with the
     claimed entity location(s) the developer supplied);
   - the step 4 hash table for every tracked document on disk (`file`, `sha256` or null) — the
     agent records these verbatim into the manifest and never hashes input documents itself
     (not in Column-Update Mode, where step 4 is skipped and the agent instead carries the
     existing manifest's `docs` array forward);
   - in TARGETED UPDATE: the classified change set (changed / new / deleted / renamed, with old
     and new hashes), the current manifest's per-document `modules` mapping, the affected-module
     union, and the developer's deleted-doc disposition;
   - that whenever it writes the brief it writes `docs/output-specs/.brief-state.json` in the
     same action — and only then;
   - that it must follow its own agent definition end to end — Phases 0 through 5, Targeted
     Update Mode, or Column-Update Mode — and return its Phase 5 report.

7. **Relay gate reports per the mechanic.** The agent CANNOT pause for user input mid-run. If it
   hits a gate — for doc-analyst that is the Phase 4 overwrite gate, in targeted update,
   regeneration, and Column-Update Mode alike — it stops, writes nothing, and returns a
   structured GATE REPORT as its final output: the gate name, what it needs, the diff, and
   enumerated options with a recommended default. In Targeted Update Mode the gate diff must also
   confirm that every module outside the affected set is byte-identical, Status lines included.
   Present that report to the developer verbatim and collect the developer's decision. RELAUNCH
   the agent with the decision included in the launch prompt ONLY when the decision requires the
   agent to act (an approved overwrite); a relaunch re-runs the same mode with the same change
   set. A keep or abort decision ends the flow — do not relaunch, and close with a one-line
   statement that nothing was written and the existing brief, manifest, and statuses are
   untouched. Never answer a gate on the developer's behalf. If the agent instead returns its
   Phase 0 stop message (the documents directory vanished or emptied between preflight and
   launch), relay that message verbatim and STOP.

8. **Present the results.** Relay the agent's Phase 5 report in full: the coverage summary
   (documents processed and skipped, each skipped file with its reason and conversion request,
   plus the "Inaccessible sources" list), the counts, the Compliance Profile summary, open
   questions (at most 2, each with enumerated options and a recommended default), and next steps.

   The closing block below applies ONLY when PROJECT_BRIEF.md was actually written this run. If
   the run wrote nothing — a Column-Update report whose location verifications all failed, or a
   keep decision at the overwrite gate — relay the agent's report and end with the one-line
   nothing-was-written statement instead. When a brief WAS written, close with exactly this
   instruction:

   > PROJECT_BRIEF.md is at docs/output-specs/PROJECT_BRIEF.md; its change manifest
   > docs/output-specs/.brief-state.json sits beside it; docs/decisions.md was scaffolded if it
   > was absent.
   > 1. Review and verify the Compliance Profile (Section 5) now — an incomplete profile creates
   >    exposure, an overbroad one creates review noise. Until you confirm it, the fail-closed
   >    rule stays active: every agent treats all person-related data in this system as PHI.
   >    Resolve any "PHI (presumed — unconfirmed)" rows by answering the open questions above.
   > 2. This command is repeatable. Rerun it whenever input documents change — it detects
   >    changed, new, and deleted files via the manifest and offers a targeted update of the
   >    affected modules (their Status flips to DRAFT) or a full regeneration, both through the
   >    diff-and-approval gate. Where Implemented updates run in Column-Update Mode.
   > 3. Commit PROJECT_BRIEF.md, docs/output-specs/.brief-state.json, and docs/decisions.md —
   >    every other agent in the pipeline reads them instead of the original documents.
   > Next step: when your module-wise user-story workbooks are in <DOCS-DIR>, run /gap-analysis
   > to validate them against the brief and certify modules FINAL. Then /research-ticket <KEY>
   > or /create-spec <KEY> for your first ticket.
