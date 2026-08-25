# purandar-ai plugin suite

Reusable Claude Code plugin suite for Thinkitive development teams. It packages
a pipeline of specialist AI agents that take a Jira ticket from research to spec
to implementation, grounded in each project's own SRS and conventions, with
HIPAA compliance built in at every layer.

This one repo is a marketplace hosting **three plugins**, so each repo loads
only what it needs — a frontend developer's session never carries Spring Boot
agent definitions, and vice versa:

| Plugin | Ships | Enable it in |
|---|---|---|
| `ai-agent` (core) | All 6 pipeline/review agents, all 8 commands, shared-standards + hipaa + audit-logging skills, all templates, all safety/observability hooks, the helper scripts | Every repo using the suite |
| `ai-agent-backend` | `backend-springboot` implementer agent + spring-boot skill | Backend (Java/Spring Boot) code repos |
| `ai-agent-frontend` | `frontend-react` implementer agent + react skill | Frontend (React) code repos |

The suite carries **how to work** (workflows, quality rules, compliance rules,
spec formats). Each consuming project supplies **what it is** (stack, structure,
domain, requirements). Nothing here assumes any specific project infrastructure:
agents discover the stack from `pom.xml` / `build.gradle` / `package.json`,
domain knowledge from the project's SRS, and precedent from the project's own
decision log.

## Deployment topologies

**Single repo** — everything in one repo: enable core plus the stack plugin(s)
you need; all `docs/` paths are the repo's own. No pointer file, and behavior
is exactly as it was before 2.0.0.

**Multi-repo (shared project context)** — a BE repo, an FE repo, and a
project-context repo cloned side by side. The context repo holds the shared
`docs/` tree (input documents, brief, gap report, tickets, decision log, the
project-wide metrics trend); each code repo carries a one-line pointer file
`.claude/ai-agent.json` (`{"contextRoot": "../project-context/docs"}`) and
every command reads and writes the shared context through it. A pointer that
does not resolve is a hard stop — never a silent fallback. The metadata-only
events log stays in whichever repo the session runs in.

```
parent/
├── project-context/   enables ai-agent            (docs/ tree lives here)
├── backend/           enables ai-agent + ai-agent-backend    pointer -> ../project-context/docs
└── frontend/          enables ai-agent + ai-agent-frontend   pointer -> ../project-context/docs
```

`/setup-repo` writes all of this configuration for you (see Installation).

## Agents

| Agent | Plugin | Role | Posture |
|---|---|---|---|
| `doc-analyst` | ai-agent | Reads the SRS, meeting minutes, and design links, distills `PROJECT_BRIEF.md`; on reruns updates only the modules whose inputs changed | Read-heavy, writes brief + change manifest + decision-log scaffold only |
| `gap-analyst` | ai-agent | Compares the developer's module-wise user stories (`.xlsx`) against the brief; reports every gap with both sides cited | Read-only; writes the regenerated gap report only |
| `jira-researcher` | ai-agent | Excavates a Jira ticket: description, all comments, links, attachments, Figma designs | Jira read-only; writes research file only |
| `spec-writer` | ai-agent | Turns research into a locked-template tech spec | Writes spec only |
| `frontend-react` | ai-agent-frontend | Implements from the approved spec (React/TypeScript) | Full implementation |
| `backend-springboot` | ai-agent-backend | Implements from the approved spec (Java/Spring Boot); SOLID/KISS/YAGNI/DRY as review rules; audit-logging expertise | Full implementation |
| `hipaa-compliance` | ai-agent | Reviews code and specs for PHI violations; severity-ranked report with corrected code | Read-only |
| `agent-auditor` | ai-agent | Grades how the pipeline handled a ticket: event-log process checks + template conformance | Read-only; writes scorecard + trend row only |

Agent names are globally unique across the suite; commands launch them by bare
name. `/implement` preflights that the stack plugin its spec needs is enabled
and stops with enable instructions when it is not.

## Commands

All commands ship in the core plugin. `docs/` paths land in the context repo —
in single-repo mode that is the repo itself; with a pointer, the shared sibling.

| Command | What it does | Generates |
|---|---|---|
| `/setup-repo` | One-time bootstrap: asks the repo's role (Backend / Frontend / Project Context), then merges the marketplace, plugin enablement, and permissions into `.claude/settings.json` and writes the context pointer for code repos. Merge-safe, re-run safe | `.claude/settings.json` (merged), `.claude/ai-agent.json` (pointer mode) — the developer reviews and commits |
| `/onboard-project` | Sweeps stale user-level agents (`~/.claude/agents/`) with your approval first, then reads `docs/input-specs/` (SRS, meeting minutes, design links, other documents) and distills project knowledge. Repeatable: reruns detect changed/new/deleted inputs via the change manifest and offer a targeted update of just the affected modules (flipped to DRAFT) or a full regeneration | `docs/output-specs/PROJECT_BRIEF.md` (module-wise, per-module DRAFT/FINAL status), `docs/output-specs/.brief-state.json`, scaffolds `docs/decisions.md` |
| `/gap-analysis` | Compares the module-wise user-story `.xlsx` workbooks in `docs/input-specs/` against the brief (agent is report-only), then walks each gap's resolution with you, records approved resolutions as `GAP-` decision entries, and certifies fully aligned modules FINAL — iterate until every module reads ALIGNED and FINAL | `docs/output-specs/GAP_ANALYSIS.md` (regenerated per run), `GAP-` appends to `docs/decisions.md`, Section 11 FINAL flips |
| `/research-ticket <KEY>` | Full ticket excavation via Atlassian MCP (read-only) | `docs/tickets/<KEY>/research.md` |
| `/create-spec <KEY>` | Research (or inline lightweight research) to tech spec | `docs/tickets/<KEY>/tech-spec.md` |
| `/implement <KEY>` | Implements the approved spec with the stack-appropriate agent | Code + tests |
| `/hipaa-check [path]` | Standalone compliance scan, usable any time | Severity-ranked report |
| `/agent-audit <KEY>` | Grades pipeline process + artifact conformance for one ticket (report-only) | `docs/tickets/<KEY>/audit.md`, row in `docs/agent-metrics.md` |

`/research-ticket` is optional — `/create-spec` does its own lightweight research
when no research file exists. Two approval gates are always mandatory: the spec
approval gate (the developer approves the tech-spec before `/implement` runs) and
the plan gate (inside `/implement`, before code is written). Conflicts between
sources and unresolved cross-stack dependencies are additional full stops — see
the shared-standards skill for the canonical gate definitions.

## The developer workflow

```
Once per repo:      /setup-repo (writes settings + pointer; commit them) -> fresh session
Once per project:   drop SRS + MOMs + design links in docs/input-specs/ (auto-created in the context repo) -> /onboard-project
Requirement change: update the documents in docs/input-specs/ -> /onboard-project (targeted update of affected modules, or full regeneration)
Story iteration:    drop user stories (.xlsx) in docs/input-specs/ -> /gap-analysis -> resolve gaps (recorded as GAP- decisions) -> fix inputs -> repeat until every module is ALIGNED and FINAL
Once per developer: accept plugin install prompt -> authorize Atlassian connector (OAuth); Figma connector when designs live in Figma
Per ticket:         [/research-ticket] -> /create-spec -> review spec -> /implement -> review diff -> PR
```

Human checkpoints: the developer approves the spec (spec approval gate), the
implementation plan (plan gate), and reviews the final diff. Jira access is
read-only, with ONE approval-gated exception: after implementing one stack of a
cross-stack ticket in the multi-repo topology, `/implement` drafts a handoff
comment and — only on the developer's explicit approval of the exact text —
posts it to the ticket via the developer's own Atlassian connector. Figma
access — used to read design frames behind Figma links — is
read-only through each developer's own Figma connector, and without it agents
request exported frames instead of guessing. All generated artifacts are
committed to the context repo — the code repo itself in single-repo mode, the
shared project-context repo in the multi-repo topology.

Two contracts are additionally harness-enforced by safety hooks shipped with the
core plugin (see `plugins/ai-agent/hooks/`): git write operations (commit/push/tag creation, `gh pr create/merge`)
are denied — the developer commits, never the plugin — and file writes containing
secret-shaped or SSN-shaped values are denied before they reach disk. Test
enforcement is deliberately NOT a hook: the implementer agents own test coverage
(both with a hard rule against weakening tests; the backend agent additionally
never lowers a coverage threshold, adds an exclusion, or deletes a quality-gate
rule), and the consuming project's CI on the pull request is the deterministic
backstop.

The plugin also scaffolds its own workspace: a SessionStart hook idempotently
creates `docs/input-specs/` (the drop zone for everything the pipeline reads —
SRS, MOMs, design links, module-wise user-story `.xlsx` files) and
`docs/output-specs/` (where project-level generated artifacts land — the brief
and the gap-analysis report), each with a README explaining what belongs there.
It is guarded so a personally-installed plugin never litters unrelated repos:
it only runs where the repo enables the plugin in `.claude/settings.json` or
already has a `docs/` tree, and it skips repos whose `.claude/ai-agent.json`
context pointer says the docs tree lives in a sibling context repo (that repo
scaffolds itself). If the hook could not run, nothing degrades
silently: the commands' preflights stop and tell the developer exactly which
folders to create and what to place in them. Per-ticket outputs stay in
`docs/tickets/<KEY>/`.

The plugin also observes itself: a PostToolUse hook logs metadata-only events
(skill loads, agent spawns, standards reads, artifact writes, safety-hook
denials — never file content, commands, or prompts) to
`.claude/ai-agent-metrics/events.jsonl` in the consuming repo. `/agent-audit <KEY>`
turns that log plus the ticket's artifacts into a report-only scorecard
(`docs/tickets/<KEY>/audit.md`) and appends a trend row to `docs/agent-metrics.md`;
`plugins/ai-agent/scripts/aggregate-metrics.sh <repo>...` merges those trend
files into one team-wide report for leads — in the shared-context topology,
point it at the project-context repo(s), where the trend file lives.

## Installation

### Bootstrap (first person on the project)

1. Install the marketplace and core plugin once on your machine:

   ```
   /plugin marketplace add AdityaP2024/purandar-agentic-ai
   /plugin install ai-agent@purandar-ai
   ```

2. In each repo, run `/setup-repo`, answer "which repo is this?" (Backend /
   Frontend / Project Context), review the settings diff it shows, and commit
   the file(s) it writes. That is the whole setup: it merges the marketplace,
   the right `enabledPlugins` for the repo's role, the sibling-directory
   permission, and — for code repos in the multi-repo topology — the context
   pointer.

### Everyone else

Nothing manual. Opening a configured repo in Claude Code prompts you to install
the plugins that repo enables — accept once per machine. Installs use your
existing GitHub credentials.

What `/setup-repo` produces per repo type (for reference, or to write by hand):

| Repo type | `enabledPlugins` | `.claude/ai-agent.json` pointer |
|---|---|---|
| Backend code repo | `ai-agent` + `ai-agent-backend` | `../project-context/docs` (or none in single-repo mode) |
| Frontend code repo | `ai-agent` + `ai-agent-frontend` | same |
| Project-context repo | `ai-agent` | never — it IS the context root |
| Single repo (everything) | `ai-agent` + needed stack plugin(s) | none — local `docs/` |

```json
// .claude/settings.json (backend code repo, multi-repo topology)
{
  "extraKnownMarketplaces": {
    "purandar-ai": {
      "source": { "source": "github", "repo": "AdityaP2024/purandar-agentic-ai" }
    }
  },
  "enabledPlugins": {
    "ai-agent@purandar-ai": true,
    "ai-agent-backend@purandar-ai": true
  },
  "permissions": {
    "additionalDirectories": ["../project-context/docs"]
  }
}
```

## Repository structure

```
.claude-plugin/               marketplace.json only (this repo is its own marketplace;
                              each plugin carries its own plugin.json)
plugins/ai-agent/             the CORE plugin
  .claude-plugin/plugin.json
  agents/                     6 agent definitions (YAML frontmatter: name, description with
                              dispatch examples; tool posture enforced by body hard rules)
  commands/                   all 8 slash-command workflows (the orchestration layer)
  skills/                     shared-standards, hipaa, audit-logging
  templates/                  locked output formats: research, tech-spec, project-brief,
                              gap-report, decisions log
  hooks/                      harness-enforced hooks (hooks.json + scripts/): git-write guard,
                              secret/PHI write guard, metadata-only observability event
                              logger, workspace scaffolder — active in every consuming repo
  scripts/                    aggregate-metrics.sh (team-wide trend report);
                              xlsx-extract.py (python3 stdlib; .xlsx workbooks -> TSV)
plugins/ai-agent-backend/     backend-springboot agent + spring-boot skill (+ plugin.json)
plugins/ai-agent-frontend/    frontend-react agent + react skill (+ plugin.json)
docs/                         suite-wide docs: AGENT-CATALOG.md, GETTING-STARTED.md
```

Layering rules: **agents** hold persona and hard rules, **skills** hold patterns
and reference knowledge, **commands** hold workflow and orchestration,
**templates** hold locked output contracts. Process never leaks into skills;
knowledge never leaks into commands. The one deliberate exception is
`shared-standards`, which carries the cross-cutting process contracts (gates,
budgets, taxonomies) every agent must obey regardless of which command invoked it.

## Versioning

Semantic versioning via `version` in each plugin's `.claude-plugin/plugin.json`.
The three plugins version in **lockstep** — always the same number, bumped
together — because the stack agents' contracts are hard-coupled to the core's
templates and skills; lockstep avoids a compatibility matrix. Consuming projects
pick up new versions when a developer runs `/plugin marketplace update` —
updates never land silently mid-sprint.

## Contributing

- Every agent and command file must have valid YAML frontmatter (CI-enforced).
- No secrets, ever. Jira access is per-user OAuth via the Atlassian connector.
- No absolute paths, no pinned library versions, no project-specific constants —
  agents discover the consuming project's reality at runtime.
- Severity labels are text (`VIOLATION > RISK > BEST-PRACTICE`,
  `BREAKING > WARNING > SUGGESTION`), corrected code is mandatory for the top tier.
- CHANGELOG tables live in agent files only; command files carry none.
- Subagents cannot pause mid-run for user input: any gate hit inside an agent returns
  a structured gate report to the launching command, which presents it to the developer,
  collects the decision, and relaunches the agent only when the decision requires action.
- Hook scripts (`plugins/ai-agent/hooks/scripts/`) must pass `bash -n`, be executable, fail OPEN
  when `jq` is missing (they are defense-in-depth, never the only line of defense), and never
  echo a matched secret or PHI value back in their block messages.
- Cross-plugin references never use `${CLAUDE_PLUGIN_ROOT}` file paths (it resolves to each
  plugin's own root — CI lints this): stack agents load core skills by namespaced Skill name
  (`ai-agent:shared-standards`), and agents are launched by their globally-unique bare names.
- The three plugins version in lockstep; the CHANGELOG stays single at the repo root, entries
  naming the plugin they touch.
