---
name: onboard-project
description: Onboard a project for the AI pipeline via the doc-analyst agent — read every document in the documents directory (default docs/input-specs/), distill docs/output-specs/PROJECT_BRIEF.md, and scaffold docs/decisions.md if absent. Begins with a standalone-agent hygiene sweep — user-level agents in ~/.claude/agents/ are inventoried and, with the developer's approval, moved aside so stale definitions stop loading into every session. When module-wise user-story .xlsx workbooks are present, gap analysis runs automatically right after the brief is written. Runs once per project; rerun only after a material SRS change or for a Where Implemented column update, both through the diff-and-approval overwrite gate.
argument-hint: [docs-dir]
---

# /onboard-project

Thin orchestrator. This command validates inputs, runs preflight checks, launches the `doc-analyst`
agent, and presents its results. It NEVER reads the source documents, distills the brief, or writes
any part of `PROJECT_BRIEF.md` or `docs/decisions.md` inline — that is the agent's job, defined in
`${CLAUDE_PLUGIN_ROOT}/agents/doc-analyst.md`.

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
   documents directory, as a path relative to the consuming repo root. Call the resolved directory
   `<DOCS-DIR>` below.

2. **Preflight.** Run every check. Each check either passes, informs, or STOPS with its message —
   never silently degrade, never improvise a fallback.

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
      > <DOCS-DIR>: the SRS, meeting minutes (MOMs), design links or exported frames, and the
      > module-wise user-story .xlsx workbooks — and rerun /onboard-project.

   b. **Regeneration detection.** Check whether `PROJECT_BRIEF.md` exists at the consuming repo
      root. If it does, tell the developer now that regeneration rules apply: the agent will build
      the new brief in memory, stop without writing anything, and return a gate report containing
      the diff between the current brief and the proposed one; this command presents that report
      and relaunches the agent with the developer's decision.

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

4. **Report the mode before launching.** One short block, so the developer knows what is about to
   happen:

   - FULL ONBOARDING: "PROJECT_BRIEF.md does not exist — doc-analyst will read every document in
     <DOCS-DIR> completely and write the brief directly."
   - REGENERATION: "PROJECT_BRIEF.md exists — doc-analyst will re-read <DOCS-DIR>, rebuild the
     brief in memory, and return a diff gate report for your approval before anything is written."
   - COLUMN-UPDATE: "Where Implemented update only — doc-analyst will verify the claimed location
     and return a diff gate report; no documents are re-read."

   Include the step 2c decision-log note in this block.

5. **Launch the doc-analyst agent** via the Task/Agent mechanism with a prompt that states
   precisely:

   - the documents directory `<DOCS-DIR>` (the agent uses it everywhere its definition says
     `docs/input-specs/` and names it in Sections 9 and 10 of the brief);
   - whether `docs/output-specs/PROJECT_BRIEF.md` already exists in the consuming repo (Phase 4 overwrite gate
     applies if so);
   - whether `docs/decisions.md` already exists (scaffold copied verbatim only if absent; an
     existing file left untouched);
   - the mode: full onboarding, regeneration, or Column-Update Mode (with the claimed entity
     location(s) the developer supplied);
   - that it must follow its own agent definition end to end — Phases 0 through 5, or Column-Update
     Mode — and return its Phase 5 report.

6. **Relay gate reports per the mechanic.** The agent CANNOT pause for user input mid-run. If it
   hits a gate — for doc-analyst that is the Phase 4 overwrite gate, in regeneration and
   Column-Update Mode alike — it stops, writes nothing, and returns a structured GATE REPORT as
   its final output: the gate name, what it needs, the diff, and enumerated options with a
   recommended default. Present that report to the developer verbatim and collect the developer's
   decision. RELAUNCH the agent with the decision included in the launch prompt ONLY when the
   decision requires the agent to act (an approved overwrite); a keep or abort decision ends the
   flow — do not relaunch, and close with a one-line statement that nothing was written and the
   existing brief is untouched. Never answer a gate on the developer's behalf. If the agent
   instead returns its Phase 0 stop message (the documents directory vanished or emptied between
   preflight and launch), relay that message verbatim and STOP.

7. **Present the results.** Relay the agent's Phase 5 report in full: the coverage summary
   (documents processed and skipped, each skipped file with its reason and conversion request,
   plus the "Inaccessible sources" list), the counts, the Compliance Profile summary, open
   questions (at most 2, each with enumerated options and a recommended default), and next steps.

   The closing block below applies ONLY when PROJECT_BRIEF.md was actually written this run. If
   the run wrote nothing — a Column-Update report whose location verifications all failed, or a
   keep decision at the overwrite gate — relay the agent's report and end with the one-line
   nothing-was-written statement instead. When a brief WAS written, close with exactly this
   instruction:

   > PROJECT_BRIEF.md is at docs/output-specs/PROJECT_BRIEF.md; docs/decisions.md was scaffolded if it was absent.
   > 1. Review and verify the Compliance Profile (Section 5) now — an incomplete profile creates
   >    exposure, an overbroad one creates review noise. Until you confirm it, the fail-closed
   >    rule stays active: every agent treats all person-related data in this system as PHI.
   >    Resolve any "PHI (presumed — unconfirmed)" rows by answering the open questions above.
   > 2. This command runs once per project. Rerun it only after a material SRS change, or to
   >    update the Where Implemented column — both paths return a diff gate report for your
   >    approval before anything is overwritten.
   > 3. Commit PROJECT_BRIEF.md and docs/decisions.md — every other agent in the pipeline reads
   >    them instead of the original documents.
   > Next step: /research-ticket <KEY> or /create-spec <KEY> for your first ticket.

8. **Chain into gap analysis — automatic.** This step runs ONLY when `PROJECT_BRIEF.md` was
   actually written this run (full onboarding, or an approved regeneration overwrite). It never
   runs after Column-Update Mode, a keep/abort decision at the overwrite gate, or a stopped run.

   - Check `<DOCS-DIR>` for `.xlsx` user-story workbooks.
   - If at least one exists: print one line — "Module-wise user stories detected ({n} workbook(s))
     — running gap analysis automatically." — then execute the `/gap-analysis` command
     (`${CLAUDE_PLUGIN_ROOT}/commands/gap-analysis.md`) end to end exactly as if the developer had
     run it: its preflights, the gap-analyst launch, the verbatim relay, and its closing. The
     developer runs `/gap-analysis` directly only for the LATER iterations (after supplying
     corrections), never for this first pass.
   - If none exists: close with exactly this line instead — "No user-story workbooks (.xlsx)
     found in <DOCS-DIR>. When you drop the module-wise user stories there, run /gap-analysis to
     validate them against the brief."
