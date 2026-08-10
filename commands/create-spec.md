---
name: create-spec
description: Turn a Jira ticket into the locked-template tech spec at docs/tickets/<KEY>/tech-spec.md via the spec-writer agent — from existing /research-ticket output when present, or from inline lightweight research when not. Ends at the spec approval gate; the developer approves before /implement runs.
argument-hint: <TICKET-KEY>
---

# /create-spec

Thin orchestrator. This command validates inputs, runs preflight checks, launches the `spec-writer`
agent, and presents its results. It NEVER researches the ticket, designs the solution, or writes
any part of the spec inline — that is the agent's job, defined in
`${CLAUDE_PLUGIN_ROOT}/agents/spec-writer.md`.

## Instructions

1. **Parse the argument.** `$ARGUMENTS` must contain exactly one Jira issue key: a project key of
   uppercase letters and digits starting with a letter, a hyphen, and a number (for example
   `PLAT-421` or `P2-123`). Trim whitespace before checking.
   If `$ARGUMENTS` is empty or does not match that shape, print exactly this and STOP:

   > Usage: /create-spec <TICKET-KEY>
   > Example: /create-spec PLAT-421
   > The key must be a Jira issue key (PROJECT-123 form; digits are allowed in the project key,
   > e.g. P2-123).

   Call the validated key `<KEY>` below.

2. **Preflight.** Run every check. Each check either passes, warns, or STOPS with its message —
   never silently degrade, never improvise a fallback.

   a. **Mode detection.** Check whether `docs/tickets/<KEY>/research.md` exists in the consuming
      repo. Present means RESEARCH-BASED mode; absent means INLINE LIGHTWEIGHT mode.

   b. **Atlassian MCP reachability — required only in INLINE LIGHTWEIGHT mode.** Inline research
      fetches the ticket live, so the user's Atlassian MCP connector must be available. Verify the
      Atlassian MCP tools are present and usable in this session. If they are not, print this and
      STOP:

      > Cannot create a spec for <KEY>: docs/tickets/<KEY>/research.md does not exist, so
      > spec-writer must fetch the ticket live, and the Atlassian MCP connector is not available
      > in this session. Fix either side and rerun:
      > - authorize the Atlassian connector (claude.ai connector settings, or /mcp in an
      >   interactive session), then rerun /create-spec <KEY>, or
      > - run /research-ticket <KEY> from a session where the connector works, then rerun
      >   /create-spec <KEY>.

      In RESEARCH-BASED mode the MCP is OPTIONAL: do not stop and do not block on it. If it is
      unavailable, note it in the launch prompt so the agent skips live verification and records
      the limitation per the shared-standards partial-context protocol.

   c. **PROJECT_BRIEF.md check — warn, do not stop.** If `docs/output-specs/PROJECT_BRIEF.md` is
      missing from the consuming repo, print this warning and continue:

      > WARNING: PROJECT_BRIEF.md not found. spec-writer will fall back to direct repo search for
      > entity mapping, and the hipaa skill's fail-closed rule will treat all person-related data
      > as PHI. For better grounding, run /onboard-project first.

   d. **Existing spec check.** If `docs/tickets/<KEY>/tech-spec.md` already exists, tell the
      developer now that regeneration rules apply: the agent will build the new spec in memory,
      stop without writing anything, and return a gate report containing the diff; this command
      presents that report and relaunches the agent with the developer's decision. Same-ticket
      regeneration is never supersession; cross-ticket supersession happens only on explicit
      developer direction and follows the template's banner rules (Rule 4).

3. **Report the mode before launching.** One short block, so the developer knows what grounding
   the spec will have:

   - RESEARCH-BASED: "Found docs/tickets/<KEY>/research.md — spec-writer will build on it."
   - INLINE LIGHTWEIGHT: "No research.md for <KEY> — spec-writer will do inline lightweight
     research (read-only Jira fetch plus repo scan). This is shallower than /research-ticket; if
     the ticket turns out to be complex, the agent will recommend stopping to run
     /research-ticket <KEY> first."

   Include any step 2 warnings in this block.

4. **Launch the spec-writer agent** via the Task/Agent mechanism with a prompt that states
   precisely:

   - the ticket key `<KEY>`;
   - the mode (RESEARCH-BASED with the research.md path, or INLINE LIGHTWEIGHT);
   - whether the Atlassian MCP is available this session (and in research-based mode, that it is
     optional);
   - whether `docs/tickets/<KEY>/tech-spec.md` already exists (diff + approval flow required);
   - whether this spec supersedes a DIFFERENT ticket's spec (only when the developer explicitly
     directed it), with the superseded spec's path; absent by default;
   - whether `PROJECT_BRIEF.md` exists (fail-closed PHI handling if not);
   - that it must follow its own agent definition end to end — Phases 0 through 5 — and return
     its Phase 5 report.

   The agent CANNOT pause for user input mid-run. If it hits a gate — the inline-mode complexity
   pause, a conflict gate, or the overwrite diff — it stops, writes
   nothing, and returns a structured GATE REPORT as its final output: the gate name, what it
   needs, the diff or both quoted sides where applicable, and enumerated options with a
   recommended default. Present that report to the developer verbatim, collect the developer's
   decision, and RELAUNCH the agent with the decision included in the launch prompt ONLY when the
   decision requires the agent to act (an approved overwrite, continue-inline at the complexity
   pause, or a conflict resolution); a keep or abort decision ends the flow with a one-line
   statement that nothing was written. Never answer a gate on the
   developer's behalf. Draft decision entries are NOT gates — they arrive inside the agent's
   Phase 5 report (after the spec is written) and are handled exclusively by step 6; never
   relaunch the agent to handle a decision entry.

5. **Present the results.** Relay the agent's Phase 5 report in full: approach summary, the
   coverage counts line (`AC coverage: N EXISTING, N FRONTEND-ONLY, N BACKEND-REQUIRED,
   N CROSS-STACK`), open questions, inaccessible sources, and any draft decision-log entries
   awaiting developer approval.

6. **Append approved decision-log entries.** For each drafted decision-log entry the developer
   explicitly approves, THIS COMMAND appends the entry plus its Index row to `docs/decisions.md`.
   If `docs/decisions.md` does not exist, copy `${CLAUDE_PLUGIN_ROOT}/templates/decisions.md` to
   `docs/decisions.md` verbatim first (scaffold creation, not a decision append — mirroring the
   doc-analyst exception), then append the approved entry plus its Index row.
   Never append silently, never append a draft the developer has not approved, and subagents
   never write that file.

7. **Close with the spec approval gate** — only when a new spec was actually written. If the
   agent returns a stop message instead of a Phase 5 report or gate report, relay it verbatim and
   STOP. If the developer's gate decision was to keep the existing spec, state that nothing was
   written and end without the closing block. Otherwise close with exactly this instruction:

   > The spec is at docs/tickets/<KEY>/tech-spec.md with Approval Status: DRAFT.
   > 1. Review it — Section 5 is what implementers will use verbatim.
   > 2. Resolve any Section 12 open questions yourself: fold each resolution into Section 3 (or
   >    direct a regeneration), then set Section 12 to NONE.
   > 3. If Section 2 contains SPEC-WRITER-DERIVED acceptance criteria, confirm or correct them
   >    before approving.
   > 4. When satisfied, edit Section 13 yourself: flip the Approval Status line from DRAFT to
   >    "APPROVED by {name} on {YYYY-MM-DD}". Neither this command nor the agent ever writes
   >    APPROVED.
   > Next step after approval: /implement <KEY>. It refuses to run while the status is DRAFT.
