---
name: implement
description: Implement an APPROVED tech-spec at docs/tickets/<KEY>/tech-spec.md via the backend-springboot and frontend-react agents — backend first, then frontend once its Section 7 dependencies are RESOLVED. Refuses to run while the spec's Approval Status is DRAFT; the plan gate precedes any code; the developer commits — the plugin never does.
argument-hint: <TICKET-KEY>
---

# /implement

Thin orchestrator. This command validates the spec approval gate, computes the execution order,
launches the implementer agents, relays their gate reports, performs the two main-session writes
the pipeline reserves for it (Section 7 RESOLVED flips and approved decision-log appends), and
presents results. It NEVER writes source code, tests, or migrations inline — that is the
implementers' job, defined in `${CLAUDE_PLUGIN_ROOT}/agents/backend-springboot.md` and
`${CLAUDE_PLUGIN_ROOT}/agents/frontend-react.md`.

Unlike the agents it launches, this command runs in the main session: it MAY pause for developer
input between steps and between agent launches, and several steps below require it to. The agents
cannot pause — every mid-run decision they need comes back as a structured gate report that this
command relays.

Neither this command nor any implementer ever runs `git commit` or `git push`. The developer
reviews and commits.

## Instructions

1. **Parse the argument.** `$ARGUMENTS` must contain exactly one Jira issue key: a project key of
   uppercase letters and digits starting with a letter, a hyphen, and a number (for example
   `PLAT-421` or `P2-123`). Trim whitespace before checking.
   If `$ARGUMENTS` is empty or does not match that shape, print exactly this and STOP:

   > Usage: /implement <TICKET-KEY>
   > Example: /implement PLAT-421
   > The key must be a Jira issue key (PROJECT-123 form; digits are allowed in the project key,
   > e.g. P2-123).

   Call the validated key `<KEY>` below.

2. **Preflight — verify everything on disk.** Run every check in order. Each check either passes,
   warns, or STOPS with its message — never silently degrade, never improvise a fallback. The
   tech-spec is a locked template parsed by its numbered section headings; read the sections named
   below directly from the file.

   a. **Spec existence.** `docs/tickets/<KEY>/tech-spec.md` must exist in the consuming repo. If
      it does not, print exactly this and STOP:

      > No tech-spec for <KEY>. Run /create-spec <KEY> first.

   b. **Supersession banner.** If the spec begins with the SUPERSEDED banner, print this and STOP:

      > docs/tickets/<KEY>/tech-spec.md is SUPERSEDED — its banner says: "Do NOT implement from
      > this document." Replaced by: {path or identifier from the banner}. Run /implement against
      > the replacing ticket's key instead.

   c. **Spec approval check.** Read the Approval Status line in Section 13 (Provenance). It must
      read exactly `APPROVED by {name} on {YYYY-MM-DD}` — a real name and a real date in that
      exact form. Anything else — `DRAFT`, a missing line, a variant wording, a malformed date —
      fails the spec approval gate. On failure, print this (quoting the actual line found) and
      STOP:

      > Cannot implement <KEY>: the spec approval gate is not passed.
      > Section 13 Approval Status currently reads: "{the actual line, verbatim}"
      > /implement requires exactly: APPROVED by {name} on {YYYY-MM-DD}
      > Review docs/tickets/<KEY>/tech-spec.md — Section 5 is what the implementers will use
      > verbatim — resolve any Section 12 open questions, then flip the Approval Status line
      > yourself to that exact form and rerun /implement <KEY>. Neither this command nor any
      > agent ever writes APPROVED, and both implementer agents independently refuse to proceed
      > while the line is DRAFT or malformed.

      If the Approval Status line IS the exact APPROVED form but Section 12 (Open Questions) is
      not NONE, the approval is malformed by the template's own rule — both implementer agents
      independently stop on it, so print the same malformed-approval stop here at preflight
      instead of launching, and STOP:

      > Cannot implement <KEY>: Section 13 reads APPROVED but Section 12 is not NONE — the
      > approval is malformed by the template's own rule. Leftover open questions:
      > "{the Section 12 content, verbatim}"
      > Resolve each question, fold the resolution into the spec, set Section 12 to NONE,
      > re-confirm the approval, and rerun /implement <KEY>.

   d. **Work split.** Parse Section 2 (AC Coverage Mapping) coverage labels and Section 7
      (Cross-Stack Dependencies). Before doing anything else, report the split in exactly this
      form:

      `Work split: N EXISTING / N FRONTEND-ONLY / N BACKEND-REQUIRED / N CROSS-STACK; Section 7:
      N rows (N UNRESOLVED, N RESOLVED)`

      If every AC is EXISTING, skip to the all-EXISTING closing in step 8 — there is nothing to
      implement and no agent is launched.

   e. **Context checks — inform, do not stop.** Check whether `docs/tickets/<KEY>/research.md`
      exists, whether `PROJECT_BRIEF.md` exists at the consuming repo root, and whether
      `docs/decisions.md` exists; each fact goes into the launch prompts. If `PROJECT_BRIEF.md`
      is missing, print this warning and continue:

      > WARNING: PROJECT_BRIEF.md not found. The implementers will fall back to direct repo
      > discovery, and the hipaa skill's fail-closed rule will treat all person-related data as
      > PHI. For better grounding, run /onboard-project first.

      Do NOT check for, wait on, or block on the Atlassian MCP connector — the implementers do
      not need Jira. Note its availability only as an informational fact for the launch prompts.

3. **Determine the execution plan and confirm it.** Backend work is implemented first:

   - **Backend scope**: BACKEND-REQUIRED ACs plus the backend side of CROSS-STACK ACs. If any
     Section 7 row with Blocked Side `backend` is UNRESOLVED (for example blocked on an external
     team), the backend work depending on it MUST NOT start — the cross-stack hard gate permits
     no mocks, stubs, or workarounds; that work is deferred until the developer marks the row
     RESOLVED.
   - **Frontend scope**: FRONTEND-ONLY ACs plus the frontend side of CROSS-STACK ACs. Frontend
     work whose Section 7 dependencies are UNRESOLVED is deferred: for rows the backend portion
     of THIS run will satisfy, the expected path is backend first, developer review, RESOLVED
     flip (step 5), then frontend in the same run. FRONTEND-ONLY work with no blocking rows can
     run in the same pass after backend completes — or immediately, when no backend work exists.
   - If nothing can launch (all remaining work blocked by UNRESOLVED rows this run cannot
     satisfy), say which rows block what, print the one-line nothing-was-written statement from
     step 8, and STOP.

   Announce the plan to the developer: what launches first, what follows in this pass and on what
   condition, and what is deferred with the Section 7 row numbers that block it. Then PAUSE and
   confirm before launching anything — do not proceed on silence.

4. **Launch backend-springboot** (when backend work exists) via the Task/Agent mechanism with a
   prompt that states precisely:

   - the ticket key `<KEY>` and the spec path `docs/tickets/<KEY>/tech-spec.md` (Section 13
     verified APPROVED at preflight; the agent re-verifies at its own Phase 0);
   - whether `docs/tickets/<KEY>/research.md` exists;
   - whether `PROJECT_BRIEF.md` exists at the consuming repo root (fail-closed PHI handling if
     not) and whether `docs/decisions.md` exists;
   - whether the Atlassian MCP is available this session — informational only; the implementers
     do not need Jira and never block on it;
   - the scope of this run per step 3: for backend, all backend work or the named subset of
     Section 2 BACKEND-REQUIRED/CROSS-STACK rows this launch covers; for frontend (step 6), the
     FRONTEND-ONLY rows and the frontend half of named CROSS-STACK rows whose Section 7 rows
     read RESOLVED on disk;
   - any developer decision carried from a prior gate report of this flow;
   - that it must follow its own agent definition end to end — Phases 0 through 7 — and return
     its Phase 7 report.

   **Relay gate reports per the standard mechanic.** The agent CANNOT pause mid-run. When a gate
   fires it stops, writes nothing further, and returns a structured GATE REPORT as its final
   output: the gate name, what it needs, the evidence, and enumerated options with a recommended
   default. Present that report to the developer verbatim, collect the decision, and RELAUNCH the
   agent with the decision in the launch prompt ONLY when the decision requires the agent to act.
   A relaunch re-runs the agent's full workflow from Phase 0, executing the carried decision
   instead of re-firing the gate. Never answer a gate on the developer's behalf. The gates:

   - **Plan gate — always fires, before any code.** The report carries Files to Create / Files to
     Modify / Existing Code Reused / Risks, with options: A — proceed with the plan as presented
     (recommended default); B — revise the plan (the developer states what to change; the
     relaunched agent re-plans and fires the plan gate again); C — abort. Nothing is written
     before approval. A and B require a relaunch; C ends the flow with the one-line
     nothing-was-written statement.
   - **New-dependency gate.** A dependency discovered necessary mid-implementation is never added
     silently: the report names the dependency, why existing code cannot serve, and the
     alternatives. Approving it or directing an alternative requires a relaunch; an abort ends
     the flow — and because this gate can fire after code exists, report what the agent says was
     already written so the developer can review or revert.
   - **Conflict gate.** Both sides quoted verbatim with each source named, per the
     shared-standards conflict authority matrix. A resolution requires a relaunch.
   - **Cross-stack hard gate** (agent Phase 0). The report quotes the blocking Section 7 rows
     verbatim. Options B (narrowed scope) and C (developer-directed stale-row flip via step 5,
     then relaunch) require a relaunch; Option A ends this launch with the work deferred.
   - **Contract-gap gate** (a Section 5 gap the agent cannot close without guessing). Option A
     ends the flow — the developer resolves the gap in the spec, re-confirms approval, and
     reruns /implement <KEY>; Option B aborts.

   If the agent returns a Phase 0 stop message instead of a gate report or Phase 7 report — its
   own spec approval refusal, or any other stop — relay it verbatim and STOP.

5. **Present the backend Phase 7 report in full**, addressed to the developer: the files created
   and modified, the AC coverage checklist in the exact shared-standards format, the test
   commands and their results — failures are presented as failures, with output; the agents never
   claim done on a red suite and never weaken a test to make it pass — out-of-scope items and
   assumptions, and any draft decision-log entries (handled by step 7).

   **Then run the Section 7 transition** (when Section 7 rows block frontend work): ask the
   developer to review the backend work now — the diff and the test results. When satisfied, the
   developer explicitly instructs this command which Section 7 rows to mark RESOLVED (for example
   "mark Section 7 rows 1 and 2 RESOLVED"). On that explicit instruction — and only then — THIS
   COMMAND edits `docs/tickets/<KEY>/tech-spec.md`, changing ONLY the Status cell of the named
   rows from UNRESOLVED to RESOLVED: never any other cell, row, or section, and never a row the
   developer did not name. This is the only spec edit this command ever performs. Without that
   instruction, blocked frontend work stays blocked — record it as deferred for the closing. The
   developer may instead edit the spec directly; either way, step 6 re-reads Section 7 from disk.

6. **Launch frontend-react** (when frontend work exists and every Section 7 row blocking it reads
   RESOLVED on disk — or no row blocks it) with the same input contract and the same gate-relay
   mechanic as step 4. Re-read Section 7 from `docs/tickets/<KEY>/tech-spec.md` immediately
   before launching; name any still-UNRESOLVED rows in the launch prompt so the agent excludes
   the dependent work — its own cross-stack hard gate independently enforces this. Frontend work
   still blocked is deferred to a later `/implement <KEY>` run. Present its Phase 7 report in
   full, exactly as in step 5.

7. **Append approved decision-log entries.** For each decision-log entry drafted in either
   agent's Phase 7 report that the developer explicitly approves, THIS COMMAND appends the entry
   plus its Index row to `docs/decisions.md`. If `docs/decisions.md` does not exist, copy
   `${CLAUDE_PLUGIN_ROOT}/templates/decisions.md` to `docs/decisions.md` verbatim first (scaffold
   creation, not a decision append), then append the approved entry plus its Index row. Never
   append silently, never append a draft the developer has not approved, and the implementers
   never write that file. Draft entries are NOT gates — they arrive inside Phase 7 reports; never
   relaunch an agent to handle one.

8. **Close.** Three mutually exclusive endings:

   - **Code was written this run** (by either agent, including a partial write before a mid-run
     abort). Merge the AC coverage checklists from the Phase 7 reports into a single list covering
     every AC in the spec, in the exact shared-standards format: implemented ACs checked with
     their files; EXISTING ACs checked as covered by existing code per Section 2; deferred or
     aborted ACs unchecked with the reason (an unchecked AC without a reason is a defect). Name
     the test results per stack — honestly, failures included. Then close with exactly:

     > Review the diff, run the app if needed, and commit the code together with
     > docs/tickets/<KEY>/ artifacts. The plugin never commits for you.

     Follow with any deferred work and what unblocks it: the Section 7 rows still UNRESOLVED,
     that the developer marks them RESOLVED (through this command's step 5 transition or by
     editing the spec), and that rerunning `/implement <KEY>` picks the deferred work up.

   - **Nothing was written** (an aborted plan gate, a declined step 3 confirmation, an immediate
     stop, or nothing launchable): say exactly that in one line — "Nothing was written this run:
     {reason}." — and end.

   - **All-EXISTING spec** (from step 2d): close by saying the spec found existing code covers
     every AC — there is nothing to implement — and recommend the developer verify the Section 2
     evidence (the files, endpoints, and components its How column names) before closing the
     ticket.
