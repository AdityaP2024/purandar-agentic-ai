# Changelog

All notable changes to the purandar-ai plugin suite. Versioning follows semver via
each plugin's `.claude-plugin/plugin.json` — the three plugins version in lockstep;
consuming projects pick up releases with `/plugin marketplace update`.

## 2.3.1 — 2026-09-05

### react skill: portability fixes — rules no longer assume infrastructure a project may lack

2.3.0's rules were frequently written as "through the project's X" — a field wrapper, a response
envelope, a theme object, a contract-test tier, an error reporter. That phrasing reads as *X
exists*, so in a project shaped differently the agent could treat a normal absence as a gap to
fill, and build framework inside a feature ticket. This release makes absence an explicit, valid
branch everywhere it applies.

**Seven rules hedged in the reference files:**

| Rule | Was | Now |
|---|---|---|
| Field wrapper | "Every field goes through the project's field wrapper" | Where one exists, use it; otherwise wire label + error + association directly, and raise the wrapper as a plan-gate observation |
| Response envelope | "Unwrap a response envelope once, in the seam" | Only where the backend wraps responses — an API returning bare payloads needs no layer |
| Theme singleton | "Theme is a module singleton" | Only where the project constructs a runtime theme object; CSS-custom-property and utility-class projects have none and need none |
| Contract tests | "Contract tests lock a primitive's prop API" | Where the project has that convention; otherwise an ordinary behavior test covering the same variants suffices — do not introduce a new test tier |
| Error reporting | "Errors reach a reporting destination" | Where the project has one; **error tracking is never added by a feature ticket** |
| Promotion threshold | "Promote at the second or third consumer" | A judgment call once there are two or three real consumers, not a threshold applied mechanically |
| Shared primitives in the main bundle | stated as always true | Only for a primitive genuinely used by most routes; check actual usage rather than assuming a shared folder means shared use |

**Five more in the router card:**
- **Rule 4 (state ownership)** — where the project has no cache layer or form library, the outcome still holds: one owner per piece of state, no second copy that can drift.
- **Rule 9 (assemble, never fork)** — where no shared primitive exists for what is needed, build the screen plainly and note the candidate; **do not build a framework inside a feature ticket**.
- **Three checklist lines** (transport seam, registries, error reporting) reworded so they pass in a project that lacks the infrastructure.

**One new universal principle**, so this generalizes beyond the twelve cases above:

> Where the project HAS the named infrastructure, use it; bypassing it is a finding. Where it does
> NOT, the rule still names an **outcome** — achieve it with what the project already has, and name
> the missing piece as an observation. Building the infrastructure itself inside a feature ticket
> is scope creep and a finding.

Plus a conflict rule: where an outcome and an existing convention appear to clash, **the convention
wins for _how_ and the outcome still holds for _what_** — and if both genuinely cannot hold, that
is a conflict to surface, not to resolve silently.

**Deliberately not hedged**, because they are outcome rules that hold on any architecture: race-condition guards, keyboard operability, loading/empty/error states, no-literals-where-a-token-exists, and behavior-over-implementation testing.

- Content-only release: no structural, hook, command, template, or contract changes.

## 2.3.0 — 2026-09-05

### react skill: router + on-demand reference files (progressive disclosure)

2.2.0 put the full frontend standard in one 600-line `SKILL.md`, which loaded in full on every
frontend run. Claude Code's guidance is that a skill over ~500 lines should split into a router
plus supporting files that load only when referenced. This release does that, and closes the
coverage gaps 2.2.0 left open.

**Structure.** `SKILL.md` is now a ~180-line router carrying a routing table, twelve always-on
rules, and the Self-Review Checklist. Twelve reference files under `skills/react/references/`
hold the detail and are read on demand:

`theme-and-tokens` · `state-and-persistence` · `async-and-data` · `forms-and-contract` ·
`error-handling` · `responsiveness` · `accessibility` · `performance` · `code-quality` ·
`testing` · `cross-browser` · `security-and-gating`

**Token cost per run** — the point of the change:

| Run | Loaded |
|---|---|
| 2.2.0, any task | ~11,300 tokens (whole card, always) |
| 2.3.0, styling-only change | ~4,200 tokens (router + 1 file) |
| 2.3.0, typical data screen with a form | ~9,700 tokens (router + 6 files) |
| 2.3.0, worst case (every file) | ~16,800 tokens |

The common cases get cheaper and the detail gets deeper; only a task genuinely touching every
area pays more than before.

**New coverage (the gaps 2.2.0 missed):**
- **Race conditions and cancellation** — the out-of-order response bug (type `ann` then `anna`,
  the `ann` response lands last and wins), its three correct fixes, and the rule that no async
  resolution may write state without a cache key, a cancellation, or a freshness guard. Promoted
  to an always-on rule; also a required test scenario.
- **Concurrent rendering** — `useDeferredValue` / `useTransition` guidance, with the warning that
  they change scheduling, not the amount of work, and must never wrap an urgent input update.
- **Web Vitals** — LCP / INP / CLS / scroll-fps targets, and the rule that a performance claim
  without a measurement is a finding.
- **`prefers-reduced-motion`** — a WCAG requirement absent from 2.2.0's 13 standards.
- **Error reporting** — errors reach a reporting destination, sensitive fields stripped; source
  maps emitted but not referenced by shipped JS.
- **Polling and real-time** — interval discipline, stop-when-hidden, reconnect with backoff,
  writes through the cache layer.
- **File upload** — pre-validation, per-file progress, partial failure, per-request timeout.
- **Focus management gaps** — focus on route change, and focus when the focused element is
  removed (never stranded on `body`).
- **Client-side security** — unsanitized HTML, secrets in the bundle, CSP, hosted payment
  elements, idle timeout, dependency audits.
- **Multi-tenant / multi-context isolation** — one source of truth, one injection point, clear
  the cache on any context change, fail loud on a missing context.
- **Effects discipline** — effects synchronize with the outside world; deriving state in an
  effect is a finding.

**Explicit anti-scope-creep rule.** A new always-on rule states that a capability the project has
deliberately not adopted — internationalization in an English-only product, dark mode in a
single-theme product, offline support in an always-connected tool — is NOT added because this
card mentions it. Discover what the project does and match it; an unrequested capability is a
finding. This directly answers the risk of a broader standard pushing unwanted work.

### frontend-react agent
- **Phase 2** now walks the routing table and reads only the reference files whose triggers match
  the ticket, naming them in the plan-gate report so the developer sees which standards the run is
  held to.
- **Phase 6** checks the skill's Self-Review Checklist, re-reading each reference file relevant to
  what the run touched.
- Skill-load description rewritten for the router structure.

- No hook, command, template, or contract changes; no behavior change for backend work.

## 2.2.0 — 2026-09-05

### react skill: production-grade frontend coverage (177 -> 600 lines)

The `react` engineering-standards skill grew from a focused card into a full frontend
foundation, so the `frontend-react` agent applies responsiveness, theming, accessibility,
persistence and error-handling rules by default instead of only when a spec names them.
Distilled from a production React/TypeScript design system; every project-specific fact
(library names, versions, brand values, directory layouts) was deliberately excluded — the
card still pins nothing and discovers everything.

**New sections (7):**
- **Theme and Design Tokens** — every colour/spacing/radius/shadow/type/breakpoint from the
  token source; no hex, no raw px, no magic numbers in screens; multiplying token scales;
  semantic ramps over saturated mids; theme-layer styling; module-singleton theme; fluid type
  with a 16px body floor; multi-theme token discipline.
- **Config-Driven Registries** — routes, nav, permissions, statuses, icons, constants and PHI
  rules declared once and read by screens; registry colours are token keys; unknown keys fail
  soft; semantic icon indirection; copy beside what it names.
- **Config-Driven Primitives** — assemble from config + props, never fork per screen; identity
  vs state split; capabilities enabled by presence of their data, never by a boolean flag.
- **State Persistence and Refresh-Safety** — the three tiers (path / query / local ergonomics);
  one shared URL-state primitive; omit defaults, replace-not-push, reset page on filter change,
  same-write clearing of deeper params, coerce-and-fall-back; storage always wrapped, versioned
  and purged on context switch; history-back over hardcoded paths.
- **Data Structures and Algorithms** — match the structure to the hot operation; named
  algorithms over nested conditionals; fresh containers on write; explicit don't-over-engineer
  guidance.
- **Error Handling** — error boundaries at two levels; one typed error mapper (transport before
  status, retry 5xx/network only, single-flight refresh); a catch never names a cause it did not
  check; toast-vs-screen map; the four loading rules; offline as a state; mock and real layers
  rejecting identically so error paths survive integration.
- **Cross-Browser Compatibility** — support matrix as contract; sticky, overscroll, virtualized
  height, focus-visible, viewport units, zoom, high-DPI, and the rounded-input autofill fix.

**Substantially expanded:**
- **Responsiveness** — promoted from one bullet to a full section: the no-break table, the
  bounded-box `min-height: 0` chain, structural swaps vs styling, mobile chrome behaviours,
  equal-height grids, and a layout definition-of-done.
- **Accessibility and Keyboard** — from three bullets to the 13 standards plus ARIA patterns
  and focus management.
- **Testing** — added contract tests for silent ordering rules, type-checked test files,
  environment-stub semantics, and a scenario-coverage catalog (list / form / detail / hook /
  utility / cross-cutting) on the principle that line coverage is not scenario coverage.
- **Permission Gating**, **Forms**, **Date/Time**, **Performance** — new dedicated sections.
- **Discover the Stack First** — six new discovery rows (tokens, breakpoints, icons, datetime,
  lint constraints) plus monorepo dependency-isolation.
- **Component Quality / TypeScript** — decomposition destinations over raising limits;
  memoization prerequisites; narrow subscriptions; type-level invariants; strict-index handling.

**Key Conventions Summary: 17 -> 54 rows.** This table is what the agent's Phase 6 self-review
runs against, so every new rule is mechanically checked rather than merely read. All 17 original
rows are preserved verbatim in meaning.

### frontend-react agent
- Phase 4 implementation rules widened to reach the new sections: responsiveness now names the
  no-break rules and bounded-box chain; accessibility names the 13 standards; state ownership
  gained the persistence tier; two new items cover design tokens/registries and named error
  surfaces. List renumbered 1-15.
- Skill-load description updated to list the skill's full section set.

- No hook, command, template, or contract changes; no behavior change for backend work.

## 2.1.1 — 2026-09-03

### /setup-repo: context-repo detection and role-correct closings
- **Step 3 now detects before it asks**: for code repos it probes the conventional
  `../project-context/docs` and, when absent, scans the sibling directories for a `docs/` tree
  (ranking ones with `output-specs/`/`input-specs/` first) and offers each detected candidate
  by name as a selectable answer — a renamed context repo no longer requires typing its path
  by hand. New explicit option **"Context repo not available yet"**: the pointer is written now
  with the path the repo will have.
- **Step 8 asks instead of warn-and-proceed**: an unresolvable contextRoot at write time now
  offers "provide the correct path" (re-runs detection) or "not ready yet — write anyway",
  the latter closing with an explicit TODO (clone it at {path}; pipeline commands stop with a
  pointer error until then; setup itself never needs rerunning).
- **Step 9 closing rewritten as three exhaustive, role-correct branches** — Project Context /
  code repo pointer mode / code repo single-repo mode. Fixes the defect where a Backend repo
  setup could close with the Project Context repo's "drop the SRS in and run /onboard-project"
  message. Pointer-mode code repos are now told their actual next steps (/research-ticket →
  /create-spec → /implement or /implement-batch) and that onboarding/gap-analysis belong to
  the context repo's owner and are never run here.
- **docs/GETTING-STARTED.md**: new "Who runs what" paragraph in the Topologies section
  (context-repo owner runs /onboard-project + /gap-analysis; BE/FE developers start at
  /research-ticket); Step 0 walkthrough updated for the detection flow.
- No contract, hook, agent, or behavior-at-runtime changes — messaging and setup-flow only.

## 2.1.0 — 2026-08-25

### New command: /implement-batch — parallel ticket implementation in git worktrees
- Implements several APPROVED tickets in one run, each on its own `feature/<KEY>` branch in its
  own `.worktrees/<KEY>` git worktree, launched in parallel via the SAME stack agents and gate
  mechanics as `/implement` (plan gate always first, gate reports relayed, relaunch with the
  developer's decision). No new agent: selection (explicit keys, or interactively — manual
  entry or the developer's open-sprint To Do tickets via JQL), per-ticket preflight, dependency
  analysis, scheduling, and all reserved writes are main-session command logic.
- **Frontier-only scheduling.** Each run implements only tickets that are ready NOW; everything
  else is DEFERRED with the reason and unblock step named (no spec, spec not approved, blocked
  by an unfinished Jira-linked issue, footprint conflict, over cap, leftover branch/worktree).
  Dependencies come from two layers: Jira `is blocked by` links (read-only; skipped with a loud
  warning if the MCP is unavailable) and deterministic file-footprint intersection of the
  specs' Section 4 Affected Components — two tickets touching the same file are never built
  from the same base in one run, because their branches would collide at merge time regardless
  of scheduling. Plan-gate reports are cross-checked the same way before implementation, so
  overlap the specs did not predict (test files, shared configs) is caught too. Blocked
  tickets are never chained onto unreviewed branches; merging and rerunning is the wave
  mechanism.
- **Hard caps: 5 tickets per run, 3 agents in flight** — lowerable at the batch gate, never
  raisable. Parallelism buys wall-clock time, not fewer tokens; the caps protect the
  developer's rate-limit window, machine (simultaneous builds), and review capacity.
- **The git carve-out — the suite's ONE exception to "the plugin runs no state-changing git".**
  `/implement-batch` may run exactly `git fetch` and `git worktree add .worktrees/<KEY> -b
  feature/<KEY> <base>`, both only after the batch gate explicitly approves the listed
  operations. Commits, pushes, tags, and PRs remain the developer's alone — block-git-writes
  already passes `worktree add`/`fetch` and keeps denying `commit`/`push`/`tag`/`gh pr`
  everywhere, including inside worktrees (no hook change needed). The command never removes a
  worktree or deletes a branch; cleanup commands are handed to the developer, and an aborted
  ticket's worktree + branch delete without a trace.
- **Lean closing, durable detail.** The chat closing is one table (ticket, outcome, branch,
  tests) plus the review loop, deferred-wave steps, and cleanup commands. Each ticket's full
  Phase 7 report is appended by the main session to a new artifact,
  `docs/tickets/<KEY>/implementation-report.md` in the context repo (dated run sections;
  agents never write it). Decision-log drafts from parallel agents are renumbered to the next
  free IDs at append time (announced), so concurrent drafts cannot collide. Cross-repo Jira
  handoff comments are batched under the same 2.0.1 approval gate.

### Contracts
- shared-standards: new **Source Root** rule in the Context Root section (a launch prompt may
  pin an agent to a `.worktrees/<KEY>` worktree — source paths, stack discovery, builds, and
  tests run against it; `docs/` paths keep resolving under the shared context root; the
  worktree's own pointer copy is ignored); Artifact Conventions gains the
  implementation-report row; the gates table and roster name `/implement-batch`.
- Stack agents (backend-springboot, frontend-react): Inputs accept `/implement-batch` as a
  launching command and the optional SOURCE ROOT fact. No behavioral change outside batch runs.
- `.worktrees/` ignore guard: the batch preflight checks `git check-ignore .worktrees` and, at
  the batch gate, offers the one-line `.gitignore` append when missing (`/setup-repo` is
  unchanged — its two-file contract holds).

## 2.0.1 — 2026-08-24

### Commands
- `/implement` step 2f is now topology-aware. Previously a mixed (cross-stack) spec refused to
  run in a repo that enables only one stack plugin — exactly the shape the multi-repo topology
  creates on purpose. Now: all needed stacks available → proceed; SOME available → implement
  this repo's scope and DEFER the other stack's rows to `/implement <KEY>` in the sibling repo
  (the designed handoff, not an error — Section 7 ordering still governs); NONE available →
  stop with enable-or-go-to-the-right-repo instructions.
- New approval-gated cross-stack handoff comment — the ONE deliberate exception to the plugin
  suite's read-only Jira posture. When `/implement` finishes one stack of a mixed ticket and
  defers the rest, it drafts a metadata-only Jira comment (ACs done, files count, Section 7
  states, where to run the remaining half; never requirement text with personal-data values)
  and asks: Post to Jira / Copy-paste myself / Skip. It posts ONLY the approved text, only on
  explicit approval, via the developer's own Atlassian connector; without the connector it
  hands over the draft to paste. Every other Jira touchpoint remains read-only.
- CHANGELOG housekeeping: the 2.0.0 heading below is dated (it shipped 2026-08-24 with the
  heading still reading "Unreleased" — the tag is correct and unmoved; consumers install by
  plugin.json version).

## 2.0.0 — 2026-08-24

### BREAKING — one plugin becomes three
- The single `ai-agent` plugin splits into a three-plugin marketplace hosted in this same repo:
  `ai-agent` (core — 6 agents, all 8 commands, shared-standards + hipaa + audit-logging skills,
  templates, hooks, scripts), `ai-agent-backend` (backend-springboot agent + spring-boot
  skill), `ai-agent-frontend` (frontend-react agent + react skill). A repo enables only what it
  needs; an FE session never carries Spring Boot definitions again. Marketplace sources are now
  `./plugins/<name>`; each plugin carries its own `plugin.json`. The three plugins version in
  lockstep.
- Cross-plugin wiring: stack agents load core skills by namespaced Skill name
  (`ai-agent:shared-standards`, `ai-agent:hipaa`, `ai-agent:audit-logging`) — never by
  `${CLAUDE_PLUGIN_ROOT}` file path (CI step 13 lints this); agents launch by their
  globally-unique bare names; `/implement` gains a stack-agent availability preflight (step 2f)
  that stops with enable instructions when the spec needs a stack whose plugin is not enabled.
- Shared project context for multi-repo projects: code repos may carry `.claude/ai-agent.json`
  with `{"contextRoot": "../project-context/docs"}` — every `docs/` path in the suite then
  resolves under the sibling context repo (shared-standards "Context Root" rule; resolution
  happens once, in each command's preflight, and is passed to agents in the launch prompt). An
  unresolvable pointer is a hard preflight stop, never a silent fallback. The scaffold hook
  skips pointer repos; the events log stays session-repo-local; ticket artifacts and
  `docs/agent-metrics.md` live in the shared context.
- New `/setup-repo` bootstrap command: asks the repo's role (Backend / Frontend / Project
  Context) and where the context lives, then merge-writes `.claude/settings.json`
  (marketplace + enabledPlugins + `permissions.additionalDirectories`) and the pointer file —
  diff shown and confirmed, unknown keys never touched, re-run safe, developer commits.

### Migration from 1.x
1. `/plugin marketplace update purandar-ai` (or remove and re-add the marketplace) so the new
   three-plugin list is seen.
2. In each repo, run `/setup-repo`, answer the repo-type question, review the settings diff,
   commit. This is the ONE required step — it adds the stack plugin your repo needs to
   `enabledPlugins`. (Manual alternative: add `"ai-agent-backend@purandar-ai": true` or
   `"ai-agent-frontend@purandar-ai": true` yourself.)
3. Single-repo projects: nothing else. With no pointer file, the context root IS the local
   `docs/` tree — every command, hook, and path behaves exactly as in 1.x.
4. Multi-repo projects (optional topology): create the shared project-context repo as a sibling
   (its docs under `docs/`), move the existing `docs/` contents there, and choose "Sibling
   context repo" in `/setup-repo` in each code repo.
5. Regenerate the brief once via `/onboard-project` (full regeneration) to gain Section 11
   statuses and seed the change manifest; pre-2.0 briefs still compare in `/gap-analysis` but
   skip FINAL certification until regenerated.
6. Start a fresh session in each repo.

### Brief lifecycle
- `/onboard-project` is now a pure, repeatable "input documents → brief" command. The automatic
  chain into `/gap-analysis` (introduced in 1.1.0) is REMOVED — run `/gap-analysis` yourself once
  the user-story workbooks are in place. The `.xlsx` workbooks are no longer mentioned as
  onboarding inputs anywhere; doc-analyst still classifies them as gap-analysis inputs, never
  brief sources.
- Manifest-driven incremental updates: every brief write also writes
  `docs/output-specs/.brief-state.json` (schemaVersion 1 — per input document: relative filename,
  sha256, last-seen date, and the brief modules it feeds; plus `briefSha256` for hand-edit
  detection). Reruns hash the input documents (main-session, in the command), classify each as
  unchanged/changed/new/deleted/renamed, and offer a TARGETED UPDATE — doc-analyst re-reads only
  the changed and new documents, recomposes only the affected sections and modules, and the gate
  diff confirms every untouched module is byte-identical — or a full regeneration. Every manifest
  failure path (missing, corrupt, wrong schema, hashing unavailable) degrades to regeneration,
  never an error. A renamed file (same hash) updates citations without flipping statuses.
- Per-module status: brief Section 11 modules carry `Status: DRAFT` or
  `Status: FINAL — aligned {date} (gap run {date})`, with a rollup bullet in Section 10.
  doc-analyst writes DRAFT on every compose or recompose and never FINAL; an input-document
  change flips affected modules back to DRAFT.
- The brief is now a function of the input documents AND `docs/decisions.md`: recorded
  resolutions constrain how conflicting or gapped requirements are stated (cited by ID), and are
  never a requirement source — so regeneration never erases gap resolutions.
- `/gap-analysis` owns the whole story phase: after the gap-analyst's report (the agent stays
  strictly report-only), the command walks each gap's resolution with the developer
  (stories-wrong / brief-sources-wrong / needs-client-clarification / skip), appends approved
  resolutions to `docs/decisions.md` as `GAP-` entries (client questions as `OPEN` entries,
  superseded when answered), and certifies modules ALIGNED this run as FINAL via a narrow
  main-session Status-line edit — the exact counterpart of `/implement`'s reserved main-session
  writes — then refreshes the manifest's `briefSha256`. A pre-2.0 brief without status fields
  still compares normally; certification is skipped with a note until the brief is regenerated.
- `plugins/ai-agent/templates/decisions.md`: new `GAP-` ID namespace row and `OPEN` status
  (deliberate contract changes, consumed by the same release);
  `plugins/ai-agent/templates/project-brief.md`: Section 11 Status bullet and Section 10 rollup
  (same); duplicate Section 11 fill-note in doc-analyst merged.
- Migration: regenerate the brief once via `/onboard-project` (full regeneration) to gain the
  Section 11 statuses and seed the manifest; then `/gap-analysis` can certify FINAL. Existing
  `docs/decisions.md` files gain the `GAP-` namespace row automatically on the first GAP- append
  (announced in the same drafted diff).

## 1.1.0 — 2026-08-24

### Workspace
- New SessionStart hook `hooks/scripts/scaffold-dirs.sh` — idempotently creates the plugin's
  two workspace directories in the consuming repo, each with a README explaining what belongs
  in it: `docs/input-specs/` (drop zone for everything the pipeline reads — SRS, MOMs, design
  links, module-wise user-story `.xlsx` files) and `docs/output-specs/` (project-level generated
  artifacts). Guarded so a personally-installed plugin never litters unrelated repos: scaffolds
  only where `.claude/settings.json` enables the plugin or a `docs/` tree already exists; never
  blocks, never overwrites, prints one context line only when it creates something.
- PATH CHANGE: the documents directory `docs/specs/` is renamed `docs/input-specs/`, and
  `PROJECT_BRIEF.md` moves from the consuming repo root to `docs/output-specs/PROJECT_BRIEF.md`
  — updated across every agent, command, skill, template, and the event-logger's path filters.
  Projects onboarded under 1.0.0 should `git mv` the old paths once (`docs/specs/` →
  `docs/input-specs/`, `PROJECT_BRIEF.md` → `docs/output-specs/PROJECT_BRIEF.md`).
  Per-ticket outputs stay in `docs/tickets/<KEY>/`; `docs/decisions.md` does not move.
- The scaffolded `README.md` inside the documents directory is never treated as a project
  document: doc-analyst excludes it from inventory, and a directory holding nothing but that
  README still triggers the onboarding preflight stop.
- CI: new "Scaffold hook smoke tests" step — creation, idempotence, never-overwrite, and the
  unrelated-repo guard.
- If the hook could not create the workspace (guard not met, hook disabled), nothing degrades
  silently: the `/onboard-project` and `/gap-analysis` preflights stop and tell the developer
  exactly which folders to create manually and what to place in them.

### Gap analysis
- `scripts/xlsx-extract.py` — converts the module-wise user-story `.xlsx` workbooks developers
  drop into `docs/input-specs/` to plain TSV agents can Read (the Read tool cannot open
  spreadsheet binaries). An `.xlsx` is a zip of XML, so this is python3 standard library only
  (`zipfile` + `xml.etree`): no pip installs, no network, reads exactly the one file it is
  given, writes nothing. Handles shared strings (including rich-text runs), inline strings,
  cached formula results, booleans, and date-styled numbers (converted to ISO dates — agents
  never see raw Excel serials); embedded tabs/newlines are escaped so one spreadsheet row is
  always one TSV line, and gaps between populated cells keep their column positions. Modes:
  whole workbook (each sheet headed `# sheet: <name>`), one sheet by name, or `--list`.
  Fails loudly (exit 1, one-line stderr) on a missing file, a non-xlsx file, or an unknown
  sheet name.
- CI: `scripts/*.py` now covered by syntax/executable checks, plus an "xlsx extraction smoke
  test" step that builds a fixture workbook in-place and asserts sheet listing, cell-type
  handling, date conversion, escaping, column-gap fidelity, and the error paths.
- `gap-analyst` agent + `/gap-analysis` command — compares the developer's module-wise user
  stories (the `.xlsx` workbooks in `docs/input-specs/`) against the brief in both directions:
  brief requirements no story covers (MISSING-STORY / PARTIAL), stories nothing in the brief
  grounds (UNSOURCED-STORY), and contradictions quoted from both sides (CONFLICT — direction
  of fix is always the developer's call). Story modules are mapped to the brief's Module
  Briefs through the Domain Glossary; unmappable modules are reported UNMAPPED with a
  disposition request, never forced. Chat gets the verdict (with delta against the previous
  run), the module status table, and top gaps; the full consolidated module-wise detail is
  regenerated whole each run at `docs/output-specs/GAP_ANALYSIS.md` (new locked template
  `templates/gap-report.md`). Report-only end to end. The first pass runs AUTOMATICALLY:
  `/onboard-project` chains into `/gap-analysis` right after the brief is written whenever
  workbooks are present; the developer runs `/gap-analysis` directly only to iterate — after
  each round of corrections — until every module reads ALIGNED.
- `PROJECT_BRIEF.md` gains locked Section 11 (Module Briefs): one subsection per functional
  module as the DOCUMENTS define them (SRS chapters, MOM decisions, Figma flows — never the
  repo layout, and never the story workbooks, which would make the comparison circular) —
  the canonical module list `/gap-analysis` compares against. doc-analyst treats `.xlsx`
  files in the documents directory as gap-analysis inputs (listed, never distilled into the
  brief, with a caveat for genuine spreadsheet sources).
- shared-standards: artifact-conventions table gains the user-story workbook and gap-report
  paths; the roster now lists every agent and command (it had also been missing
  `agent-auditor` / `/agent-audit`).

### Observability
- `hooks/scripts/log-events.sh` (PostToolUse, matcher `Skill|Task|Agent|Read|Write|Edit`) —
  appends metadata-only JSONL events to `.claude/ai-agent-metrics/events.jsonl` in the
  consuming repo: skill invocations, agent spawns, reads of standards/knowledge files
  (`SKILL.md`, `MEMORY.md`, `CLAUDE.md`, `PROJECT_BRIEF.md`, `decisions.md`, `docs/input-specs/`,
  `docs/output-specs/`, `docs/tickets/`, `templates/`), and writes to pipeline artifacts. Hard rule: never logs
  file content, command strings, prompts, or tool responses — names and paths only, so
  nothing secret-shaped or PHI-shaped can land in the log by construction. Never blocks
  (always exits 0, failures swallowed), fails silent without `jq`, rotates past ~5MB, and
  the metrics directory self-ignores via a generated `.gitignore`. This is the ground-truth
  data source for the planned `/agent-audit` command.
- Both safety hooks now log their denials to the same event log (rule/pattern names only,
  never the blocked command or matched values) — previously denials left no trace.
- CI: new "Observability hook smoke tests" step covering event capture, noise filtering,
  content-leak prevention, denial logging, and the self-ignoring metrics directory.
- `agent-auditor` agent + `/agent-audit <KEY>` command — per-ticket pipeline audit that
  cross-references the event log (process: right agent per stage, right skills loaded,
  PROJECT_BRIEF grounding, hipaa skill on PHI-relevant work, hook denials) with the ticket's
  artifacts (structure/completeness against the locked templates, never content quality).
  Every grade is PASS/WARN/FAIL/NO-DATA with cited evidence; missing event log degrades to
  artifact-only mode with NO-DATA process rows, never fabricated grades. Writes exactly two
  files: the regenerated scorecard `docs/tickets/<KEY>/audit.md` and one appended trend row in
  `docs/agent-metrics.md`. Report-only end to end — a FAIL blocks nothing, fixes nothing, and
  the developer decides what to act on.
- `scripts/aggregate-metrics.sh` — lead-facing cross-repo aggregation: merges the
  `docs/agent-metrics.md` trend files from any number of consuming repos into one team-wide
  markdown report on stdout (per-repo summary with totals, then every audit row newest-first).
  Plain bash + awk, reads exactly one file per repo, writes nothing, never runs git; repos
  without data and malformed rows are reported, never silently dropped. CI: syntax/executable
  checks now cover `scripts/`, plus a behavioral smoke test for the aggregation.

### Skills
- `shared-standards` — the Decision Log Protocol gains a deferred-controls rule: a deliberately
  postponed control (authorization, audit logging, consent handling, rate limiting) is recorded
  as a decision entry with its ending condition in Consequences, and the recorded deferral
  binds both ways — never silently implement it ("while I'm here" is scope creep against an
  owner decision) and never assume it exists when code would rely on it. Reviews still report
  the gap, citing the entry ID and stating whether the trigger condition has arrived; work
  matching the trigger says so explicitly — the deferral is due for supersession, not silent
  continuation.
- `hipaa-compliance` — Phase 2 now grades missing controls against recorded deferrals: covered
  by a deferral whose trigger has not arrived, RISK citing the entry; trigger met by the scope
  under review, full severity plus the supersession call-out; no deferral entry, graded on
  exposure alone. A deferral changes a finding's framing, never the gap's visibility.
- `spring-boot` — the Discovery Preamble table gains a cross-cutting-control-status row:
  discover which authorization and audit enforcement points actually exist in the code, plus
  `docs/decisions.md` for deliberate deferrals — never assume a control exists because the
  stack supports it, never add a deferred one unbidden.
- `hipaa` — new "Framework Error Messages — They Quote the Payload" section: messages the
  framework and its drivers generate embed the data that caused them (JSON parse errors quote
  the request body, validation failures can echo the rejected value, DB constraint violations
  name the conflicting value), so boundary handlers replace framework messages with generic
  ones — `ex.getMessage()` from a parser/validator/driver never reaches a response, and is not
  logged unless the exception type provably cannot embed data values. A pass-through handler is
  a finding even while its current messages happen to be clean.
- `hipaa` — new "42 CFR Part 2 — Substance-Use / Behavioral-Health Records" section, gated on
  the project's Compliance Profile flagging Part 2 (with an open-question fallback for plainly
  behavioral-health projects whose profile is silent): consent-verified disclosure paths,
  Part 2 data marked and separable in the data model, no silent re-disclosure, and every
  disclosure emitting an audit event (taxonomy stays in the `audit-logging` skill). Applies on
  top of the card's HIPAA rules; a no-op for projects the profile does not flag.
- `hipaa` — API Surface Rules gains a record-scoping row (child records verified against the
  parent in the path, lookups scoped to the requesting user's authorized records — the
  code-level pair of the spring-boot skill's nested-resource rule), and the error-responses row
  now points at the framework-message rule.
- `hipaa-compliance` — the Phase 1 surface-scan table enumerates the new surfaces: framework
  error pass-through at boundary handlers, unscoped child lookups, and (when the Compliance
  Profile flags Part 2) disclosure paths, consent checks, and data-model markability.
- `spring-boot` — new API Contract Safety section, seven checkable edge rules: client-supplied
  sort/filter fields validated against a per-resource allow-list (unchecked they reach the
  database as `ORDER BY` targets); guessable sequential IDs never exposed at the API edge
  (enumeration surface — and a reported WARNING on PHI-bearing resources with no external-id
  convention); server-owned fields never bound from request bodies (separate update DTOs make
  the wrong request unrepresentable); update uniqueness checks exclude the row under edit;
  nested resources verified against the parent in the path (cross-scope reads); writes spanning
  the database and a non-transactional external system ordered DB-first/external-last or
  explicitly compensated; authorization/lifecycle gates on nullable flags fail closed.
- `spring-boot` — new Configuration Binding section: related settings bind through one grouped,
  validated `@ConfigurationProperties` class whose constraints fail startup naming the bad
  property (an unconstrained field boots broken instead of not booting); `@Value` only for
  true one-offs; never re-declare framework-owned properties; never hold config in static state.
- `spring-boot` — the Discovery Preamble now counts a repo's own convention documents
  (`CLAUDE.md`, patterns/standards files) as discovery sources with the same authority as the
  code where the code follows them; doc-vs-code drift is surfaced to the developer, never
  silently resolved.
- `spring-boot` — new Dependency and Framework Upgrades section: version bumps no ticket asks
  for are a stop-and-surface (same gate as a new dependency), and upgrade verification is
  behavioral, never "it builds and boots" — migrations confirmed against the migration tool's
  own bookkeeping, previously-bound config still binding, split-out/renamed framework modules
  checked against the build file, serialization and strictness defaults asserted as API
  contract via the negative-path test harness, one version of each library on the classpath
  (a stale transitive major compiles and diverges at runtime), and a full clean rebuild after
  any type or signature change.
- `spring-boot` — new Performance Rules section: measure-first gate (performance-motivated
  complexity must cite a profile, named hot path, or spec requirement), plus six checkable
  rules — N+1 queries, collection fetch strategy, batch writes (with the `jdbc.batch_size`
  and `IDENTITY`-id caveats), caching through the repo's existing stack with cached-PHI
  treated as PHI at rest (BREAKING without hipaa-skill safeguards), no `parallelStream()`
  in request paths, and micro-optimizations confined to named hot paths.

### Commands
- `/onboard-project` — new Step 0 standalone-agent hygiene sweep: inventories user-level
  agents in `~/.claude/agents/` (name, description, last-modified staleness signal), asks the
  developer which to disable via an unmistakable-polarity multi-select ("Keep all listed"
  recommended), and moves — never deletes — approved ones to `~/.claude/agents-disabled/`
  (numeric suffix on collision). If anything was moved the run stops with a
  restart-and-rerun instruction, since already-loaded definitions only unload in a fresh
  session; a clean machine proceeds with one line. Plugin-provided agents and the consuming
  repo's team-committed `.claude/agents/` are listed for awareness at most, never touched.
  Skipped in Column-Update Mode.

## 1.0.0 — 2026-07-21

Initial release. Marketplace `purandar-ai`, plugin `ai-agent` (install string
`ai-agent@purandar-ai`), owner CoThink AI.

### Agents
- `doc-analyst` — project onboarding: reads everything in `docs/specs/` — the SRS, meeting
  minutes (latest-dated-source precedence when they supersede the SRS), interface documents,
  and Figma design links (followed read-only via the user's Figma connector, or requested as
  PNG/PDF frame exports) — and distills it into `PROJECT_BRIEF.md`, scaffolding the decision
  log; Column-Update mode for locating implementations.
- `jira-researcher` — full ticket excavation (all comments chronologically, attachments read
  visually, Figma links followed read-only, linked issues, changelog) into
  `docs/tickets/<KEY>/research.md`; Jira read-only.
- `spec-writer` — locked-template tech specs with reuse-first AC mapping, drop-in API
  contracts, cross-stack hard gate; research-based and inline-lightweight modes.
- `frontend-react` — React/TypeScript implementer; spec Section 5 verbatim, visual design
  sources (attachments + Figma frames) win UI intent, plan gate, honest test reporting.
- `backend-springboot` — Java/Spring Boot implementer; SOLID/KISS/YAGNI/DRY as review rules,
  HIPAA audit-logging expertise, plan gate, honest test reporting, and checkable test-coverage
  obligations: discovers and respects the project's configured coverage gate (never lowers a
  threshold, adds an exclusion, or deletes a quality-gate rule), negative-path tests for every
  error-mapping row, edge-case and audit-event coverage made machine-checkable.
- `hipaa-compliance` — read-only compliance reviewer; severity-ranked PHI-leak findings with
  corrected code, separate audit-gap section.

### Commands
- `/onboard-project` (once per project), `/research-ticket <KEY>` (optional),
  `/create-spec <KEY>`, `/implement <KEY>`, `/hipaa-check [path]`.

### Skills
- `shared-standards` — persona base, hard rules, conflict authority matrix (including
  latest-dated-source precedence and visual-design-source authority), gates, taxonomies,
  output contracts, decision log protocol.
- `hipaa` — the 18 Safe Harbor identifiers, never-log rules, safe-logging patterns for SLF4J
  and React/TS, minimum-necessary checklist, fail-closed rule.
- `audit-logging` — HIPAA regulatory floor, AUTH/PHI_READ/PHI_WRITE/EXPORT taxonomy,
  append-only DDL with integrity grants, 7-component Spring pattern (fail-closed correct),
  13 anti-patterns, behavioral verification checklist.
- `spring-boot` — engineering standards with principles as checkable review rules, functional
  coverage-gate definition with legacy-shortfall and cannot-run carve-outs.
- `react` — state-ownership rules, contract fidelity, component quality, discovery-first
  (no pinned versions).

### Templates
- Locked contracts for `research.md`, `tech-spec.md`, `PROJECT_BRIEF.md`, and the append-only
  `decisions.md` scaffold.

### Safety hooks
- `hooks/hooks.json` + `hooks/scripts/` — two PreToolUse hooks shipped with the plugin, active
  in every consuming repo:
  - `block-git-writes.sh` (matcher: Bash) — denies `git commit`/`push`/tag creation and
    `gh pr create|merge`; read-only git always passes. Enforces "the developer commits; the
    plugin never does."
  - `guard-writes.sh` (matcher: Write|Edit) — denies file writes containing secret-shaped
    values (GitHub/Atlassian/Slack/AWS tokens, generic sk- API keys, private-key blocks) or
    SSN-shaped values, before they reach disk; never echoes the matched value.
  - Both fail open without `jq` (defense-in-depth on top of the agents' prompt-level hard
    rules). Test enforcement is deliberately NOT a hook: the implementer agents own test
    coverage, with the consuming project's CI as the deterministic backstop.

### Docs
- `docs/AGENT-CATALOG.md` — per-agent catalog (what it knows / how to invoke / what it does /
  guardrails / provenance).
- `docs/GETTING-STARTED.md` — install (including the optional Figma connector), first run,
  first ticket, smoke test, troubleshooting.
- CI (`.github/workflows/validate.yml`) — manifest and frontmatter checks, hook
  syntax/executable checks, and hook behavioral smoke tests.
