---
name: research-ticket
description: Excavate a Jira ticket read-only via the Atlassian MCP — description, all comments, linked issues, changelog, attachments — into the locked-template research file at docs/tickets/<KEY>/research.md via the jira-researcher agent. Optional; /create-spec does its own inline lightweight research when no research file exists.
argument-hint: <TICKET-KEY>
---

# /research-ticket

Thin orchestrator. This command validates inputs, runs preflight checks, launches the
`jira-researcher` agent, and presents its results. It NEVER reads Jira, scans the codebase, or
writes any part of the research file inline — that is the agent's job, defined in
`${CLAUDE_PLUGIN_ROOT}/agents/jira-researcher.md`.

This command is OPTIONAL. `/create-spec <KEY>` runs without it, doing its own inline lightweight
research when no research file exists — that is enough for simple tickets. Run `/research-ticket`
when the ticket deserves full excavation: a long or contentious comment thread, attachment-heavy
design intent, a Sub-task whose requirements live on the parent, or a web of linked issues.

## Instructions

1. **Parse the argument.** `$ARGUMENTS` must contain exactly one Jira issue key: a project key of
   uppercase letters and digits starting with a letter, a hyphen, and a number (for example
   `PLAT-421` or `P2-123`). Trim whitespace before checking.
   If `$ARGUMENTS` is empty or does not match that shape, print exactly this and STOP:

   > Usage: /research-ticket <TICKET-KEY>
   > Example: /research-ticket PLAT-421
   > The key must be a Jira issue key (PROJECT-123 form; digits are allowed in the project key,
   > e.g. P2-123).

   Call the validated key `<KEY>` below.

2. **Preflight.** Run every check. Each check either passes, warns, or STOPS with its message —
   never silently degrade, never improvise a fallback.

   a. **Atlassian MCP reachability — ALWAYS required.** The agent reads the ticket exclusively
      through the user's Atlassian MCP connector; there is no research without it. Verify the
      Atlassian MCP tools are present and usable in this session. If they are not, print this and
      STOP:

      > Cannot research <KEY>: jira-researcher reads Jira exclusively through your Atlassian MCP
      > connector, and it is not available in this session. There is no alternative access path —
      > the agent never falls back to REST APIs or stored credentials. Authorize the Atlassian
      > connector (claude.ai connector settings, or /mcp in an interactive session), then rerun
      > /research-ticket <KEY>.

   b. **PROJECT_BRIEF.md check — warn, do not stop.** If `PROJECT_BRIEF.md` is missing from the
      consuming repo root, print this warning and continue:

      > WARNING: PROJECT_BRIEF.md not found. jira-researcher will record the Project Context
      > Cross-Check as NONE and flag that /onboard-project has not been run, and the hipaa skill's
      > fail-closed rule will treat all person-related data as PHI in the Compliance Notes. For
      > better grounding, run /onboard-project first.

      A missing `docs/decisions.md` needs no warning of its own — the agent records the
      constraining-decisions cross-check as NONE, and `/onboard-project` scaffolds the file.

3. **Existing research check.** If `docs/tickets/<KEY>/research.md` already exists, tell the
   developer now that refresh rules apply: the agent will re-excavate the ticket, build the
   replacement file in memory, stop without writing anything, and return a gate report containing
   the diff with refresh-or-keep options; this command presents that report verbatim and
   relaunches the agent with the developer's decision.

4. **Launch the jira-researcher agent** via the Task/Agent mechanism with a prompt that states
   precisely:

   - the ticket key `<KEY>`;
   - that the Atlassian MCP is available this session (preflight verified it);
   - whether `docs/tickets/<KEY>/research.md` already exists (diff + refresh-or-keep gate flow
     required);
   - whether `PROJECT_BRIEF.md` exists and whether `docs/decisions.md` exists (fail-closed PHI
     handling and NONE cross-check content when not);
   - that it must follow its own agent definition end to end — Phases 0 through 5 — and return
     its Phase 5 report.

5. **Relay gate reports.** The agent CANNOT pause for user input mid-run. If it hits a gate — for
   this agent, the overwrite gate on an existing research.md — it stops, writes nothing, and
   returns a structured GATE REPORT as its final output: the gate name, what it needs, the diff,
   and enumerated options with a recommended default. Present that report to the developer
   verbatim and collect the developer's decision. RELAUNCH the agent with the decision included
   in the launch prompt ONLY when the decision requires the agent to act (for the overwrite gate,
   an approved refresh); a keep or abort decision ends the flow — do not relaunch, and close with
   a one-line statement that nothing was written and the existing research file is untouched.
   Never answer a gate on the developer's behalf. If the agent returns a Phase 0 stop message
   instead of a gate report or Phase 5 report, relay it verbatim and STOP.

6. **Present the results.** Relay the agent's Phase 5 report in full: the two-sentence
   requirement, the acceptance-criteria count with source attributions, every conflict with its
   matrix-cited resolution or OPEN flag, open questions, and inaccessible sources. Then — only
   when `docs/tickets/<KEY>/research.md` was actually written this run (a fresh write, or a
   refresh approved through the overwrite gate) — close with exactly this instruction (a keep
   decision never reaches this closing: the flow ended at step 5 with the one-line
   nothing-was-written statement):

   > Research is at docs/tickets/<KEY>/research.md.
   > 1. Review it — settle any OPEN rows in Conflicts and Clarifications and answer the Open
   >    Questions; anything left unresolved resurfaces when the spec is written.
   > 2. Next step: /create-spec <KEY>. spec-writer will build on this research file instead of
   >    doing its own inline lightweight research.
