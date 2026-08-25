---
name: implement-batch
description: Implement several APPROVED tickets in one run, each on its own feature/<KEY> branch in its own .worktrees/<KEY> git worktree, in parallel via the same stack agents and gate mechanics as /implement. Frontier-only — a ticket blocked by unmerged work, an unapproved spec, or a footprint conflict with a higher-priority ticket is deferred with its unblock step named, never chained onto unreviewed code. Hard caps 5 tickets per run and 3 agents in flight. Carries the plugin's ONE git carve-out — it may run git fetch and git worktree add — and still never commits, pushes, or tags; the developer reviews every branch and commits.
argument-hint: [<TICKET-KEY> <TICKET-KEY> ...]
---

# /implement-batch

Thin scheduler wrapped around `/implement`'s per-ticket machinery. It selects a set of ready
tickets, proves they can proceed independently, gives each an isolated git worktree on its own
branch, and runs the SAME implementer agents (`backend-springboot`, `frontend-react`) under the
SAME gate mechanics `/implement` defines — plan gate always first, gate reports relayed, relaunch
with the developer's decision. It NEVER writes source code, tests, or migrations inline, and it
adds no new agent: every per-ticket contract (spec approval, Section 5 verbatim, cross-stack hard
gate, decision drafting) is exactly `/implement`'s.

**Frontier-only.** Each run implements only tickets that are ready NOW: spec APPROVED, not blocked
by unmerged or unfinished work, and touching no file another ticket in the run touches. Everything
else is DEFERRED with the reason and the unblock step named — never silently dropped, and never
chained onto an unreviewed branch. Merging reviewed branches and rerunning `/implement-batch` is
the wave mechanism; two tickets that touch the same file are never built from the same base in one
run, because both branches would collide at merge time no matter how they are scheduled.

**The git carve-out (the ONE exception to "the plugin runs no state-changing git").** This
command may run exactly two git write-adjacent operations: `git fetch` (to ground the branch
base — run at preflight, step 2b, announced when it runs; it moves no branch and touches no
working tree) and `git worktree add .worktrees/<KEY> -b feature/<KEY> <base>` (to create each
ticket's isolated worktree and branch — only after the step 5 batch gate is confirmed). Nothing else
changes: neither this command nor any agent ever runs `git commit`, `git push`, `git tag`, or
creates a PR — the block-git-writes hook keeps denying those everywhere, including inside
worktrees — and this command never removes a worktree or deletes a branch; cleanup commands are
handed to the developer in the closing. Worktrees and branches this command creates are
reversible workspace setup: until the developer commits, deleting them erases every trace.

Unlike the agents it launches, this command runs in the main session: it MAY pause for developer
input, and the batch gate and plan approvals below require it to. The agents cannot pause — every
mid-run decision comes back as a structured gate report that this command relays, exactly per
`/implement`.

## Instructions

1. **Select the tickets.** If `$ARGUMENTS` contains one or more Jira issue keys (each matching
   `/implement`'s key shape: uppercase project key that may contain digits, hyphen, number),
   validate each, drop duplicates, and keep the given order — earlier keys outrank later ones
   wherever this run must pick between tickets. If `$ARGUMENTS` is non-empty but contains any
   token that is not a valid key, print exactly this and STOP:

   > Usage: /implement-batch <TICKET-KEY> [<TICKET-KEY> ...]
   > Example: /implement-batch PLAT-421 PLAT-422 BILL-88
   > Every argument must be a Jira issue key (PROJECT-123 form). Run with no arguments to pick
   > tickets interactively.

   If `$ARGUMENTS` is empty, ask (AskUserQuestion): "How should this batch be selected?"

   - **Enter ticket keys** — the developer supplies the keys; keep their order as priority order.
   - **My open sprint tickets** — requires the Atlassian MCP this session (option unavailable
     otherwise — say why). Search `assignee = currentUser() AND sprint in openSprints() AND
     statusCategory = "To Do" ORDER BY rank`, read-only, show the resulting keys and summaries,
     and let the developer trim the list before continuing. Rank order is priority order.

   Zero tickets selected ends the run with the one-line nothing-was-written statement.

2. **Repo preflight.** Run every check in order; never silently degrade.

   a. **Context root** — resolve it FIRST, per the shared-standards Context Root rule, from THIS
      repo's `.claude/ai-agent.json`, exactly as `/implement` step 2 does, including its HARD
      STOP on an unresolvable pointer (same message, `/implement-batch` substituted). The
      resolved root is passed to every agent launch; it is resolved exactly once, here — NEVER
      re-derived from inside a worktree (a worktree contains a copy of the pointer file whose
      relative value does not resolve from that depth; agents are told to ignore it).

   b. **Git facts.** Confirm this is a git repository with a remote named `origin` — either
      missing is a STOP ("`/implement-batch` needs a git repository with an `origin` remote to
      branch from; use `/implement <KEY>` for single-ticket work in this tree."). Determine the
      default branch (from `git symbolic-ref refs/remotes/origin/HEAD`, falling back to asking
      the developer); run `git fetch origin <branch>` (first carve-out operation — announce it).
      If the fetch fails (offline, auth), WARN that the base may be stale and continue with the
      local `origin/<branch>`. Record `<BASE>` = `origin/<branch>` and its commit sha; every
      worktree branches from exactly this commit. The session repo's own checked-out branch and
      any uncommitted changes in it are irrelevant to the batch and are never touched.

   c. **Ignore rule.** If `git check-ignore -q .worktrees/x` fails — probe a path INSIDE the
      directory: probing `.worktrees` itself false-negatives while the directory does not exist
      yet — plan a one-line append of `.worktrees/` to this repo's `.gitignore` (skipped when the
      exact line is already present), named at the batch gate and written only on its
      confirmation. Worktree contents must never appear as untracked files in the main tree.

   d. **Atlassian MCP availability** — informational fact: it gates sprint selection (step 1),
      the dependency-link check (step 4a), and posting handoff comments (step 10c). Never block
      on it here.

3. **Per-ticket intake.** For each selected ticket, in priority order, classify it READY or
   DEFERRED(reason). Apply `/implement`'s preflight checks 2a–2f per ticket — restated here
   condensed; their stop texts become per-ticket deferral reasons rather than run-level stops:

   - `docs/tickets/<KEY>/tech-spec.md` missing under the context root → DEFERRED(NO-SPEC — run
     `/create-spec <KEY>` first).
   - Spec carries the SUPERSEDED banner → DEFERRED(SUPERSEDED — implement the replacing key).
   - Section 13 Approval Status is not exactly `APPROVED by {name} on {YYYY-MM-DD}`, or it is
     but Section 12 is not NONE → DEFERRED(SPEC-NOT-APPROVED — quote the actual line; resolve
     and flip per /implement's rules).
   - Parse Section 2 coverage labels and Section 7 rows; report the work split per ticket in
     /implement's exact one-line format. Every AC EXISTING → drop from the batch with the
     all-EXISTING note (nothing to implement; verify Section 2 evidence before closing the
     ticket) — informational, not a deferral.
   - Stack scope per `/implement` step 2f: THIS repo's enabled stack agents define the scope.
     Some rows deferred cross-repo is the designed handoff (note it; step 10c drafts the
     comment). NOTHING for this repo → DEFERRED(WRONG-STACK — run /implement-batch or
     /implement <KEY> in the {backend|frontend} repo).
   - Section 7 rows with Status UNRESOLVED blocking this repo's ENTIRE scope (external team, or
     the other stack's unbuilt half) → DEFERRED(SECTION7-BLOCKED — name the rows; the developer
     flips them RESOLVED when the blocker clears). Partially blocked → READY with the scope
     narrowed to unblocked rows; the launch prompt names the excluded rows.
   - A local branch `feature/<KEY>` already exists → DEFERRED(BRANCH-EXISTS — review or delete
     it; this command never reuses or force-recreates a branch). A leftover `.worktrees/<KEY>`
     directory → DEFERRED(LEFTOVER-WORKTREE — `git worktree remove .worktrees/<KEY>` after
     reviewing it). A remote `origin/feature/<KEY>` existing is a WARNING at the batch gate,
     not a deferral.

   Also check per ticket, informationally: `docs/tickets/<KEY>/research.md` existence, and (once
   for the run) `PROJECT_BRIEF.md` existence under the context root — with `/implement`'s
   fail-closed PHI warning when the brief is missing — and `docs/decisions.md` existence.

4. **Dependency and conflict graph** over the READY set.

   a. **Jira links (declared dependencies).** With the MCP available, read each READY ticket's
      issue links, read-only. A ticket that `is blocked by` an issue whose status category is
      not Done — including a blocker that is itself in this batch — is DEFERRED(BLOCKED-BY
      <blocker-key> — merge or finish the blocker, then rerun /implement-batch <KEY>).
      Frontier-only means a blocker in the batch NEVER makes a chain: the blocker stays in the
      run, the blocked ticket waits for its merge. MCP unavailable → print this WARNING and
      continue:

      > WARNING: Jira dependency links were not checked (Atlassian MCP unavailable). Footprint
      > conflicts are still checked from the specs. Confirm at the batch gate that no selected
      > ticket depends on unmerged work.

   b. **Footprint conflicts (undeclared dependencies).** Parse each READY spec's Section 4
      (Affected Components) paths. Any two tickets sharing ANY path — create or modify, either
      side — conflict: branches built from the same base and touching the same file collide at
      merge time regardless of scheduling. Keep the higher-priority ticket;
      DEFER the other (FOOTPRINT-CONFLICT with <key> on {paths} — merge <key> first, then rerun).
      The batch gate lets the developer swap which side stays.

   c. **Caps.** The ACTIVE set is the first 5 remaining READY tickets in priority order —
      never more, whatever was asked; the rest are DEFERRED(OVER-CAP — rerun for the next
      wave). At most 3 agents are ever in flight (step 7/9 slicing). The developer may lower
      either number at the batch gate, never raise them: the caps protect the developer's rate
      limits and machine, and more than 5 unreviewed branches is a review pile-up, not a
      speedup.

5. **Batch gate (AskUserQuestion — nothing has been created yet).** Present:

   - the ACTIVE set: per ticket — key, title, stack + scope, branch `feature/<KEY>`, worktree
     `.worktrees/<KEY>`;
   - the DEFERRED/dropped table: key, reason, unblock step — every selected ticket appears in
     exactly one of the two tables;
   - the base: `<BASE>` @ {sha}, and the fetch/staleness warning if any;
   - the planned carve-out operations, verbatim (`git worktree add .worktrees/<KEY> -b
     feature/<KEY> <BASE>` per active ticket), the `.gitignore` append when step 2c planned it,
     and any remote-branch warnings;
   - the caps in effect.

   Ask: **Proceed** (recommended) / **Adjust** (drop tickets, swap a footprint-conflict winner,
   or lower a cap — then re-run steps 4c–5 on the adjusted set) /
   **Abort** (end with the one-line nothing-was-written statement). Proceeding is explicit
   approval of the carve-out operations listed.

6. **Create the worktrees.** Apply the `.gitignore` append if planned. Then, per active ticket:
   `git worktree add .worktrees/<KEY> -b feature/<KEY> <BASE>`. A creation failure defers that
   ticket (reason: the git error, verbatim) and never aborts the batch — report it and continue
   with the tickets whose worktrees exist.

7. **Plan round.** Launch each active ticket's stack agent — in slices: at most 3 launches in
   flight, all launches of a slice sent together, the next slice only after the previous slice's
   agents have returned. In a repo with BOTH stacks enabled and a ticket needing both, this run
   implements the backend scope; the frontend half is deferred to a rerun after review (backend
   first, batch-wide — a mid-batch review pause per ticket would serialize everything). Each
   launch prompt states precisely, per `/implement` step 4's contract plus the worktree facts:

   - the resolved context root (all `docs/` paths resolve under it — the shared context repo is
     shared by every ticket in the batch);
   - the SOURCE ROOT for this run: `.worktrees/<KEY>` — a git worktree of this repo on branch
     `feature/<KEY>`; per the shared-standards Source Root rule every source-code path,
     stack-fact discovery, build, and test runs against and under it; the agent never touches
     source files outside it, and it IGNORES the worktree's own copy of `.claude/ai-agent.json`
     (the context root above is already resolved);
   - the ticket key, spec path, scope rows for this stack (excluded Section 7-blocked rows named);
   - the research.md / PROJECT_BRIEF.md / decisions.md existence facts and MCP availability;
   - that it must follow its agent definition end to end and return its report.

   The plan gate always fires first, per the agent definitions — so this round's expected output
   is one plan-gate report per ticket (Files to Create / Modify / Existing Code Reused / Risks).
   An agent that instead returns a Phase 0 stop: relay it verbatim; that ticket is deferred with
   the stop as its reason.

   **Cross-check the plans.** Normalize each plan's file lists to repo-relative paths (strip the
   `.worktrees/<KEY>/` prefix) and intersect pairwise across the batch. Plans can reveal overlap
   Section 4 did not predict (test files, shared configs, a shared contract module): any new
   overlap is a conflict to resolve in step 8 — it is never silently accepted.

8. **Plan approvals — batched.** Present every plan-gate report verbatim, one titled section per
   ticket, then ask per ticket (AskUserQuestion, at most 4 questions per call, /gap-analysis's
   batching pattern): **Approve** (recommended) / **Revise** (the developer states what to
   change; that ticket gets a re-plan relaunch carrying the instruction, and returns to this
   step) / **Abort ticket** (outcome ABORTED; its worktree and branch go to the closing's
   cleanup list).
   For each overlap step 7 found, ask explicitly which ticket proceeds — or whether both do (the
   developer may knowingly accept a future merge conflict; record that acceptance in the
   closing). A ticket the developer rules out is DEFERRED(FOOTPRINT-CONFLICT with <key> on
   {paths}); its worktree and branch join the closing's cleanup list. Never answer a plan gate
   on the developer's behalf, and never launch implementation for a plan not explicitly
   approved.

9. **Implement round.** Relaunch each approved ticket's agent with the plan approval (and any
   revision content) carried in the prompt, per the standard relaunch mechanic — same slicing,
   at most 3 in flight. Each agent returns ONE of:

   - **Phase 7 report** — the ticket is implemented in its worktree; hold the report for step 10.
   - **A mid-run gate report** (new-dependency, conflict, contract-gap, cross-stack) — relay it
     verbatim, collect the developer's decision, and relaunch that ticket with the decision when
     the decision requires the agent to act, exactly per `/implement` step 4's gate list —
     including its warnings about code already written before the gate fired. A relaunched
     ticket rejoins the slice queue; the batch does not wait idle on one ticket's decision if
     other slices are still pending — finish launching them, then return to the decision.
   - **A Phase 0 stop** — relay verbatim; the ticket's outcome is DEFERRED({the stop's reason}),
     exactly as in step 7.

   An aborted or stopped ticket's worktree is left untouched for the developer — deleting
   `.worktrees/<KEY>` and `feature/<KEY>` (closing commands) erases the partial work entirely;
   nothing it wrote can leak into the main tree.

10. **Reserved main-session writes — serial, after all agents have returned.**

    a. **Implementation reports to disk.** For each ticket with a Phase 7 report, append to
       `docs/tickets/<KEY>/implementation-report.md` under the context root (create the file on
       first write) a dated run section — `## Run {YYYY-MM-DD} — {stack} — branch feature/<KEY>`
       — carrying the report: the AC coverage checklist in the exact shared-standards format,
       files created/modified, test commands and their verbatim results (failures included —
       never soften a red suite), assumptions, out-of-scope items, and deferred rows. This file
       is why the chat closing stays lean; announce each write.

    b. **Decision-log appends.** Collect every draft entry from every Phase 7 report and present
       them together for approval, per the Decision Log Protocol. Because parallel agents draft
       numbers blind to each other, THIS COMMAND renumbers the approved entries to the next free
       IDs per namespace at append time — in ticket priority order, announcing the mapping
       (draft BE-014 → appended as BE-015) — then appends each entry plus its Index row to
       `docs/decisions.md`. Never append an unapproved draft; scaffold the file from
       `${CLAUDE_PLUGIN_ROOT}/templates/decisions.md` first if absent.

    c. **Cross-repo handoff comments** — `/implement` step 8's approval-gated Jira write, batched.
       For each implemented ticket that deferred other-stack rows cross-repo, draft the handoff
       comment in exactly `/implement`'s shape (metadata only, never personal-data values). Show
       ALL drafts, then ask per ticket (at most 4 per call): **Post to Jira** (recommended) /
       **Copy-paste myself** / **Skip**. Post ONLY approved texts, via the developer's own
       Atlassian connector; connector unavailable → present the drafts as copy-paste text with
       one line saying why, and do not ask. This remains the plugin suite's only Jira write.

    Section 7 RESOLVED flips are NOT performed mid-batch: the rows a ticket's backend work
    satisfies are flipped by the developer at review time — through `/implement <KEY>`'s step 5
    transition or by editing the spec — after which a rerun picks up the dependent half.

11. **Close — lean.** One table, every selected ticket on exactly one row:

    | Ticket | Outcome | Branch | Tests |
    |---|---|---|---|

    Outcome is IMPLEMENTED, DEFERRED({reason}), ABORTED, or DROPPED(ALL-EXISTING); Tests is the
    per-stack pass/fail summary (details live in the implementation report), or `—`. Then, in
    order:

    - **Review loop, per implemented ticket:** `cd .worktrees/<KEY>` → review the diff → run the
      app or tests as needed → commit the code → push `feature/<KEY>` → open the PR. The
      `docs/tickets/<KEY>/` artifacts live under the context root, OUTSIDE the worktree — commit
      them separately where they live (the context repo in pointer mode; this repo's own tree in
      single-repo mode; a worktree cannot `git add` paths outside itself). The plugin never
      commits for you. Detailed findings: `docs/tickets/<KEY>/implementation-report.md`.
    - **After each merge:** `git worktree remove .worktrees/<KEY>` and `git branch -d
      feature/<KEY>`. **For aborted tickets, and for any deferred ticket that got a worktree
      this run** (an agent stop, a ruled-out overlap): the same with `--force` / `-D` — for an
      aborted ticket that discards the partial work completely; for a deferred ticket it clears
      the way for its rerun, since step 3 defers leftover branches and worktrees by design.
    - **Next wave:** the deferred table's unblock steps, restated one line each — merge what
      this run produced, then rerun `/implement-batch` with the deferred keys.
    - Any accepted-overlap warning from step 8, and any handoff drafts not posted.

    If NOTHING was implemented (every ticket deferred, dropped, or aborted before code), close
    instead with "Nothing was written this run: {reason per ticket}." plus the deferred table
    and, if worktrees were created, their cleanup commands.
