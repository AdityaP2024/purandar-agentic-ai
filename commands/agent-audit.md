---
name: agent-audit
description: Grade how the plugin's agents handled one ticket, via the agent-auditor agent — cross-references the observability event log (which skills each agent actually loaded, hook denials) with the ticket's artifacts (locked-template conformance) into a PASS/WARN/FAIL scorecard at docs/tickets/<KEY>/audit.md plus one trend row in docs/agent-metrics.md. Report-only; blocks and fixes nothing.
argument-hint: <TICKET-KEY>
---

# /agent-audit

Thin orchestrator. This command validates the ticket key, runs preflight checks, launches the
`agent-auditor` agent, and relays its report. It NEVER parses the event log, grades a check, or
writes any part of the scorecard inline — that is the agent's job, defined in
`${CLAUDE_PLUGIN_ROOT}/agents/agent-auditor.md`. The audit is report-only: a FAIL blocks
nothing, and neither this command nor the agent fixes anything, touches code, or runs git.

Run it after a ticket has been through the pipeline (typically after /implement) when you want
to know whether the process was actually followed — and to grow the over-time trend in
`docs/agent-metrics.md` that shows how the plugin's agents behave across tickets.

## Instructions

1. **Parse the argument.** `$ARGUMENTS` must contain exactly one Jira issue key: a project key
   of uppercase letters and digits starting with a letter, a hyphen, and a number (for example
   `PLAT-421` or `P2-123`). Trim whitespace before checking. If `$ARGUMENTS` is empty or does
   not match that shape, print exactly this and STOP:

   > Usage: /agent-audit <TICKET-KEY>
   > Example: /agent-audit PLAT-421
   > Audits how the plugin's agents handled that ticket: process compliance from the event log
   > plus artifact conformance against the locked templates. Report-only.

   Call the validated key `<KEY>` below.

2. **Preflight.** Run both checks; never silently degrade.

   a. **Ticket directory exists.** If `docs/tickets/<KEY>/` does not exist, print this and STOP
      (do not launch the agent):

      > Nothing to audit: docs/tickets/<KEY>/ does not exist. At least one pipeline stage must
      > have run on this ticket first — /research-ticket, /create-spec, or /implement.

   b. **Event log presence — note, do not stop.** If `.claude/ai-agent-metrics/events.jsonl`
      does not exist (check `events.jsonl.old` too), tell the developer before launching:

      > NOTE: No event log found at .claude/ai-agent-metrics/events.jsonl, so this audit runs
      > in artifact-only mode: template-conformance checks still run, but every process check
      > (which agents ran, which skills they loaded, hook denials) will be NO-DATA. The log is
      > written by the plugin's observability hook from v1.1.0 on, and only on the machine
      > where the ticket's sessions ran.

3. **Launch the agent-auditor agent** via the Task/Agent mechanism with a prompt that states
   precisely:

   - the ticket key `<KEY>`;
   - whether the event log exists (full mode) or not (artifact-only mode, per preflight);
   - which of the ticket's artifacts were observed to exist at preflight time (research.md,
     tech-spec.md), plus whether `PROJECT_BRIEF.md` and `docs/decisions.md` exist;
   - that it must follow its own agent definition end to end — Phases 0 through 5 — and return
     its Phase 5 report as its entire output.

4. **Relay the report verbatim.** Present the agent's Phase 5 report in full — result counts,
   mode, every FAIL and WARN with evidence, denials, caveats, and the two paths written —
   without editing, summarizing, or re-grading it. If the agent returned its Phase 0 stop
   message instead (ticket directory vanished between preflight and launch), relay it verbatim
   and STOP.

5. **Closing** (only after a full report):

   - Point at the scorecard (`docs/tickets/<KEY>/audit.md`) and the trend file
     (`docs/agent-metrics.md`), and remind the developer both are theirs to commit or not —
     the plugin never commits.
   - If the report contains FAILs or denials: suggest — as information, never as a gate — that
     recurring FAILs across tickets in `docs/agent-metrics.md` are the signal worth acting on
     (a skill agents skip, a template section that keeps coming back empty), and that is
     exactly the feedback that improves the plugin.
