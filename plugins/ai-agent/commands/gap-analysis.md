---
name: gap-analysis
description: Compare the developer's module-wise user-story .xlsx workbooks in docs/input-specs/ against docs/output-specs/PROJECT_BRIEF.md via the gap-analyst agent — every gap (missing story, unsourced story, conflict, partial coverage) reported module-wise in chat plus one consolidated regenerated report at docs/output-specs/GAP_ANALYSIS.md. After the report, this command walks each gap's resolution with the developer, appends approved resolutions to docs/decisions.md as GAP- entries, and certifies fully aligned modules FINAL in the brief's Section 11. Run it after onboarding and after each round of corrections until every module reads ALIGNED and FINAL. The agent is report-only.
---

# /gap-analysis

Thin orchestrator. This command runs preflight checks, launches the `gap-analyst` agent, and
relays its report. It NEVER extracts a workbook, maps a module, or grades a gap inline — that
is the agent's job, defined in `${CLAUDE_PLUGIN_ROOT}/agents/gap-analyst.md`.

The gap-analyst agent is report-only: a gap blocks nothing, and the agent never edits stories,
the brief, code, or runs git. This command, in the main session, performs exactly two kinds of
writes after the report is relayed — approved gap-resolution appends to `docs/decisions.md`
(Decision Log Protocol item 2) and Section 11 Status flips to FINAL in `PROJECT_BRIEF.md` for
modules certified this run (plus the matching manifest refresh) — never any other edit. Run this
command after `/onboard-project` writes or updates the brief, and again after each round of
corrections, until every module reads ALIGNED and FINAL. The report is regenerated whole on
every run; history lives in git.

## Instructions

1. **Parse the argument.** `$ARGUMENTS` must be empty — one run always compares ALL modules
   into one consolidated report. If `$ARGUMENTS` is non-empty, print exactly this and STOP:

   > Usage: /gap-analysis (no arguments)
   > Compares every module-wise user story in docs/input-specs/*.xlsx against
   > docs/output-specs/PROJECT_BRIEF.md and regenerates the consolidated module-wise report
   > docs/output-specs/GAP_ANALYSIS.md. The agent is report-only; this command then walks gap
   > resolutions with you and certifies aligned modules FINAL.

2. **Preflight.** Run every check. Each check either passes, informs, or STOPS with its
   message — never silently degrade.

   Resolve the context root FIRST, per the shared-standards Context Root rule: read
   `.claude/ai-agent.json` at the repo root — when it carries a `contextRoot`, every `docs/`
   path in this command and the agent definition resolves under that path; without a pointer
   they are this repo's own `docs/` tree, exactly as written. A pointer that does not resolve
   to a readable directory is a HARD STOP — print exactly this and go no further:

   > /gap-analysis cannot start: this repo's .claude/ai-agent.json points at a context root
   > that does not resolve.
   > Pointer value: {contextRoot}
   > Fix the pointer, or clone the project-context repo as a sibling at that path, or delete
   > .claude/ai-agent.json to use this repo's own docs/ directory. Then rerun /gap-analysis.

   a. **Brief exists.** If `docs/output-specs/PROJECT_BRIEF.md` does not exist, print exactly
      this and STOP (do not launch the agent):

      > Gap analysis cannot start: docs/output-specs/PROJECT_BRIEF.md does not exist. Run
      > /onboard-project first — the brief distilled from the SRS, meeting minutes, and design
      > links is the baseline the user stories are compared against.

   b. **Story workbooks exist.** If `docs/input-specs/` contains no `.xlsx` file — or the
      directory itself is missing — print exactly this and STOP:

      > Gap analysis cannot start: no .xlsx user-story workbook found in docs/input-specs/.
      > (The plugin's SessionStart hook normally creates docs/input-specs/ and
      > docs/output-specs/ — if they are missing, create both folders manually.) Drop the
      > module-wise user stories there (one workbook, or one file per module) and rerun
      > /gap-analysis.

   c. **python3 available.** If `python3` is not on PATH, print exactly this and STOP (the
      extractor is python3 standard library only — no packages to install):

      > Gap analysis cannot start: python3 was not found on PATH. The workbook extractor
      > (scripts/xlsx-extract.py) needs only the python3 standard library — install python3
      > and rerun /gap-analysis.

   d. **Previous report — note, do not stop.** If `docs/output-specs/GAP_ANALYSIS.md` already
      exists, tell the developer before launching:

      > NOTE: docs/output-specs/GAP_ANALYSIS.md exists and will be regenerated whole from the
      > current inputs (the agent's report includes the delta against it). History lives in
      > git — commit the current report first if you want to keep it easy to diff.

   e. **Status fields — note, do not stop.** If the brief's Section 11 modules carry no
      `Status:` lines (a brief from before plugin 2.0.0), tell the developer before launching:

      > NOTE: the brief predates module status fields — comparison runs normally, but FINAL
      > certification will be skipped. Regenerate via /onboard-project to enable it.

3. **Launch the gap-analyst agent** via the Task/Agent mechanism with a prompt that states
   precisely:

   - the resolved context root (the agent resolves every `docs/` path in its definition under
     it — it never re-derives the pointer);
   - that the brief exists, and the `.xlsx` workbook files observed in `docs/input-specs/` at
     preflight time;
   - whether a previous `docs/output-specs/GAP_ANALYSIS.md` exists (for the delta line);
   - that it must follow its own agent definition end to end — Phases 0 through 5 — and return
     its Phase 5 report as its entire output.

4. **Relay the report verbatim.** Present the agent's report in full — the verdict line with
   delta, the module status table, top gaps with both citations, unmapped modules, inaccessible
   sources, and open questions — without editing, summarizing, re-grading, or softening it. If
   the agent returned a Phase 0 stop message instead (an input vanished between preflight and
   launch, or the brief predates module briefs and needs regenerating), relay it verbatim and
   STOP.

5. **Resolution pass** (main session; only after a full report, never after a Phase 0 stop; only
   for modules with gaps — a fully ALIGNED report skips straight to step 6).

   - When the report's total gap count exceeds 12, first ask scope in one question: **Walk all
     gaps now (Recommended)** / **Only modules I pick** / **Skip resolution this run** (the
     report stands; nothing is recorded).
   - Then walk the gaps **batched by module, in the report's Section 2 order**: one
     AskUserQuestion question per gap — header = the gap ID (G-{MOD}-{n}), question text = the
     gap's type, its one-line statement, and both citations verbatim from the report. At most 4
     questions per call and 4 options per question; more gaps in a module means additional
     calls. Exactly these four options, every time:
     1. **Stories are wrong — brief stands**: the brief and its sources are correct; the
        workbook is to be corrected.
     2. **Brief/sources are wrong — story stands**: the story reflects intent; the source
        documents (and therefore the brief) need updating.
     3. **Needs client clarification**: neither side can be confirmed — records an OPEN
        decision entry naming the question.
     4. **Skip for now**: nothing recorded; the gap simply remains in the report.
   - Selecting options 1–3 approves recording that resolution; the entry TEXT still gets one
     batch confirmation in step 6a before anything is written.

6. **Record and certify** (main session; the order is fixed — 6a, then 6b, then 6c).

   a. **Decision appends.** Compose one entry per resolved gap using the `docs/decisions.md`
      scaffold's Entry Template verbatim, checking its Index first — a resolution contradicting
      an existing entry is a conflict gate, not an append. Field mapping: Title = the one-line
      gap statement; Jira = NONE unless the developer names a ticket; Context = the gap type,
      both citations, and "gap G-{MOD}-{n} in the GAP_ANALYSIS.md run compared on {date}" (gap
      IDs are per-run, so the run date is the durable pointer); Decision = the chosen side, or
      the clarification question; Consequences = what must change before the module can align;
      Status = `Accepted` for options 1–2, `OPEN` for option 3. IDs use the `GAP-` namespace,
      sequential, next number read from the Index. Present ALL drafted entries plus their Index
      rows as one drafted diff; on the developer's explicit confirmation, THIS COMMAND appends
      them and their Index rows to `docs/decisions.md`. Never silently; the agent never touches
      the file. One-time namespace migration: if the file's ID Namespaces table has no `GAP-`
      row, also insert `| GAP- | Story-vs-brief gap resolutions from /gap-analysis |
      /gap-analysis command (main session) |` into that table, announced in the same drafted
      diff.

   b. **Certify aligned modules.** Only for modules whose Section 2 Status in THIS run's report
      reads ALIGNED: present the list and ask one question — "Certify {modules} FINAL in
      PROJECT_BRIEF.md?" with options **Yes — flip their Status lines (Recommended)** / **No —
      leave DRAFT**. On approval — and only then — THIS COMMAND edits
      `docs/output-specs/PROJECT_BRIEF.md`, changing ONLY those modules' `- Status: DRAFT` line
      to `- Status: FINAL — aligned {YYYY-MM-DD} (gap run {Compared-on date from the report's
      Section 1})`, and updating the Section 10 "Module status" rollup bullet to match — never
      any other line, cell, row, or section. These are the only brief edits this command ever
      performs — the exact counterpart of /implement's two reserved main-session writes
      (Section 7 RESOLVED flips and approved decision-log appends); the approval question quotes
      the exact line changes, satisfying the shared-standards diff-and-approval rule. A module
      already reading FINAL is left untouched. A module with no Status line (a pre-2.0 brief) is
      skipped with one line: "Brief predates module status fields — regenerate via
      /onboard-project to enable FINAL certification." If executing the flip would require
      touching anything beyond the named Status lines and the rollup bullet, STOP and report
      instead of editing. A module FINAL on disk that now shows gaps (the stories moved while
      inputs did not) stays FINAL — name the discrepancy in the closing instead of flipping
      downward: only doc-analyst demotes statuses, and only on input change.

   c. **Manifest refresh.** After any flip, recompute the brief's sha256 (`shasum -a 256`, else
      `sha256sum`) and update ONLY the `briefSha256` field in
      `docs/output-specs/.brief-state.json` — without this, the next /onboard-project would
      false-positive its hand-edit warning. If the manifest is absent, note it and continue.

7. **Closing** (only after a full report):

   > The full module-wise detail is at docs/output-specs/GAP_ANALYSIS.md. This run appended {n}
   > GAP- entr(ies) to docs/decisions.md and certified {m} module(s) FINAL in PROJECT_BRIEF.md
   > Section 11 (or: appended nothing / certified nothing). Commit GAP_ANALYSIS.md — plus
   > docs/decisions.md, PROJECT_BRIEF.md, and docs/output-specs/.brief-state.json when this run
   > changed them; the plugin never commits.
   > The iteration loop: fix what the approved resolutions direct. Corrected stories go into
   > the workbooks in docs/input-specs/ — then rerun /gap-analysis. Corrected or new source
   > documents go into docs/input-specs/ — a stale or wrong brief means running /onboard-project
   > FIRST (it detects the changes and updates the affected modules, flipping them to DRAFT),
   > then /gap-analysis. OPEN GAP- entries await client answers; when one lands, update the
   > inputs it names and rerun. Converged is every module ALIGNED and FINAL.

   If the developer disputes a specific gap, point them at its row: every gap cites both sides,
   so the disagreement is checkable directly against the cited story and brief section.
