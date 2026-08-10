---
name: gap-analysis
description: Compare the developer's module-wise user-story .xlsx workbooks in docs/input-specs/ against docs/output-specs/PROJECT_BRIEF.md via the gap-analyst agent — every gap (missing story, unsourced story, conflict, partial coverage) reported module-wise in chat plus one consolidated regenerated report at docs/output-specs/GAP_ANALYSIS.md. The first pass runs automatically at the end of /onboard-project when workbooks are present; run it directly to iterate after corrections until every module reads ALIGNED. Report-only.
---

# /gap-analysis

Thin orchestrator. This command runs preflight checks, launches the `gap-analyst` agent, and
relays its report. It NEVER extracts a workbook, maps a module, or grades a gap inline — that
is the agent's job, defined in `${CLAUDE_PLUGIN_ROOT}/agents/gap-analyst.md`. The analysis is
report-only: a gap blocks nothing, and neither this command nor the agent edits stories, the
brief, code, or runs git.

The first pass runs AUTOMATICALLY: `/onboard-project` executes this command end to end as its
final step whenever user-story workbooks (.xlsx) are present in the documents directory — the
developer never has to remember it after onboarding. Run it directly for the iterations that
follow: after each round of corrections (updated stories or documents), rerun `/gap-analysis`
until every module reads ALIGNED. The report is regenerated whole on every run; history lives
in git.

## Instructions

1. **Parse the argument.** `$ARGUMENTS` must be empty — one run always compares ALL modules
   into one consolidated report. If `$ARGUMENTS` is non-empty, print exactly this and STOP:

   > Usage: /gap-analysis (no arguments)
   > Compares every module-wise user story in docs/input-specs/*.xlsx against
   > docs/output-specs/PROJECT_BRIEF.md and regenerates the consolidated module-wise report
   > docs/output-specs/GAP_ANALYSIS.md. Report-only.

2. **Preflight.** Run every check. Each check either passes, informs, or STOPS with its
   message — never silently degrade.

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

3. **Launch the gap-analyst agent** via the Task/Agent mechanism with a prompt that states
   precisely:

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

5. **Closing** (only after a full report):

   - Point at `docs/output-specs/GAP_ANALYSIS.md` as the full module-wise detail behind the
     chat summary, and remind the developer it is theirs to commit — the plugin never commits.
   - State the iteration loop plainly: supply the missing or corrected pieces the gaps name —
     updated stories or documents into `docs/input-specs/` (a stale or wrong brief means
     /onboard-project first) — then rerun /gap-analysis; converged is every module ALIGNED.
   - If the developer disputes a specific gap, point them at its row: every gap cites both
     sides, so the disagreement is checkable directly against the cited story and brief
     section.
