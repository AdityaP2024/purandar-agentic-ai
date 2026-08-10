---
name: hipaa-check
description: Run a read-only HIPAA/PHI compliance review over code, changes, or a ticket's tech-spec via the hipaa-compliance agent — severity-ordered PHI-leak findings with corrected code, plus a separate audit-gap section — writing and changing nothing.
argument-hint: [path]
---

# /hipaa-check

Thin orchestrator. This command resolves the review scope, runs preflight checks, launches the
`hipaa-compliance` agent, and relays its report verbatim. It NEVER scans code inline, never
judges findings itself, and never fixes anything — the review is the agent's job, defined in
`${CLAUDE_PLUGIN_ROOT}/agents/hipaa-compliance.md`. This command writes nothing and changes
nothing: no files, no fixes, no git commands, no commits. The developer commits; the plugin
never does.

## Instructions

1. **Resolve the scope from `$ARGUMENTS`** (trim whitespace first). Four forms:

   - **Empty** — review the change set this session already knows about: files created or
     modified in the current conversation (for example by a just-finished /implement run),
     listed explicitly. When the session knows of no change set, fall back to the project's
     source directories, discovered from the repo layout and build files, never assumed. Never
     run git — not even read-only — to discover changes. Either way, STATE which scope was
     chosen and why before launching (for example: "No known change set this session; reviewing
     src/main and src/app").
   - **A path** — an existing file or directory: that path is the scope.
   - **A ticket key** — the standard Jira issue-key shape: a project key of uppercase letters
     and digits starting with a letter, a hyphen, and a number (for example `PLAT-421` or
     `P2-123`). The scope is `docs/tickets/<KEY>/tech-spec.md` PLUS the files its Section 4
     (Affected Components) lists. Section 4 files that do not exist yet are named to the agent
     as spec-only (nothing to trace on disk). If the tech-spec itself does not exist, print
     this and STOP:

     > No tech-spec found at docs/tickets/<KEY>/tech-spec.md. Run /create-spec <KEY> first, or
     > pass a file or directory path to review code directly.

   - **`all`** — the whole source tree. Before launching, warn the developer that a full-tree
     review can take a long time on a large repo.

   Forms are checked in this order, first match wins: existing path, then `all`, then the
   ticket-key shape — an existing file or directory always wins over any other interpretation.
   When a lower-precedence reading was also plausible (a directory named `PLAT-421`, say), state
   which form was chosen and why before launching.

   Anything else — an argument that is not an existing path, not the key shape, and not `all` —
   print this and STOP:

   > Usage: /hipaa-check [path]
   > Accepts: a file or directory path; a ticket key (reviews the tech-spec plus its Section 4
   > files); "all" (whole source tree); or no argument (this session's known changes, else the
   > source directories).

2. **Preflight.** Run both checks; never silently degrade.

   a. **Scope is non-empty.** The resolved scope must contain at least one readable file. If it
      does not, print what the argument resolved to and what to pass instead (a valid path, a
      ticket key with an existing tech-spec, or `all`), then STOP.

   b. **PROJECT_BRIEF.md check — note, do not stop.** If `docs/output-specs/PROJECT_BRIEF.md` is
      missing from the consuming repo, clearly lacks a Compliance Profile section, or that section visibly
      contains unconfirmed rows (for example "PHI (presumed — unconfirmed)"), tell the developer
      before launching (the agent independently re-evaluates completeness and may adopt
      fail-closed even when no NOTE was printed):

      > NOTE: PROJECT_BRIEF.md's Compliance Profile is missing or incomplete, so this review
      > runs fail-closed: the hipaa-compliance agent treats ALL person-related data as PHI, per
      > the hipaa skill. Expect stricter findings. Running /onboard-project narrows future
      > reviews to the project's actual PHI surface.

3. **Launch the hipaa-compliance agent** via the Task/Agent mechanism with a prompt that states
   precisely:

   - the resolved scope — the explicit file/directory list, or the tech-spec path plus its
     Section 4 files (marking any that are spec-only) — and how the scope was chosen;
   - the `PROJECT_BRIEF.md` / Compliance Profile status from preflight;
   - that it must follow its own agent definition end to end — Phases 0 through 4 — and return
     its Phase 4 report as its entire output.

4. **Relay the report verbatim.** Present the agent's report in full — verdict, fail-closed
   banner if present, scope reviewed, PHI-leak findings, Minimum Necessary observations,
   audit-gap section, both count lines, open questions — without editing, summarizing, or
   re-grading it. Two other outcomes:

   - **Preflight stop**: the agent returned its Phase 0 stop message instead of a report. Relay
     it verbatim and STOP — no closing block.
   - **Conflict-gate report**: the agent stopped at the conflict gate. Present the gate report
     verbatim, collect the developer's decision, and relaunch the agent with the decision
     included in the launch prompt. Never answer a gate on the developer's behalf.

5. **Closing** (only after a full report — never after a preflight stop):

   - If the report contains one or more VIOLATIONs: state that they should be fixed before
     merge, and that fixes flow through the normal implementation path (`/create-spec` and
     `/implement`) — or direct edits for trivial ones; the developer decides which. Neither
     this command nor the agent applies fixes or commits anything. Recommend rerunning
     `/hipaa-check` over the same scope after the fixes land.
   - If the report contains no VIOLATIONs: note that any RISK and BEST-PRACTICE items are the
     developer's call, and that rerunning `/hipaa-check` after related changes keeps the
     posture current.
