# ai-agent

Reusable Claude Code plugin for Thinkitive development teams. It packages a
pipeline of specialist AI agents that take a Jira ticket from research to spec to
implementation, grounded in each project's own SRS and conventions, with HIPAA
compliance built in at every layer.

The plugin carries **how to work** (workflows, quality rules, compliance rules,
spec formats). Each consuming project supplies **what it is** (stack, structure,
domain, requirements). Nothing here assumes any specific project infrastructure:
agents discover the stack from `pom.xml` / `build.gradle` / `package.json`,
domain knowledge from the project's SRS, and precedent from the project's own
decision log.

## Agents

| Agent | Role | Posture |
|---|---|---|
| `doc-analyst` | Reads the SRS, meeting minutes, and design links, distills `PROJECT_BRIEF.md` | Read-heavy, writes brief + decision-log scaffold only |
| `jira-researcher` | Excavates a Jira ticket: description, all comments, links, attachments, Figma designs | Jira read-only; writes research file only |
| `spec-writer` | Turns research into a locked-template tech spec | Writes spec only |
| `frontend-react` | Implements from the approved spec (React/TypeScript) | Full implementation |
| `backend-springboot` | Implements from the approved spec (Java/Spring Boot); SOLID/KISS/YAGNI/DRY as review rules; audit-logging expertise | Full implementation |
| `hipaa-compliance` | Reviews code and specs for PHI violations; severity-ranked report with corrected code | Read-only |

## Commands

| Command | What it does | Generates (in the consuming repo) |
|---|---|---|
| `/onboard-project` | Reads `docs/specs/` (SRS, meeting minutes, design links, other documents), distills project knowledge | `PROJECT_BRIEF.md`, scaffolds `docs/decisions.md` |
| `/research-ticket <KEY>` | Full ticket excavation via Atlassian MCP (read-only) | `docs/tickets/<KEY>/research.md` |
| `/create-spec <KEY>` | Research (or inline lightweight research) to tech spec | `docs/tickets/<KEY>/tech-spec.md` |
| `/implement <KEY>` | Implements the approved spec with the stack-appropriate agent | Code + tests |
| `/hipaa-check [path]` | Standalone compliance scan, usable any time | Severity-ranked report |

`/research-ticket` is optional — `/create-spec` does its own lightweight research
when no research file exists. Two approval gates are always mandatory: the spec
approval gate (the developer approves the tech-spec before `/implement` runs) and
the plan gate (inside `/implement`, before code is written). Conflicts between
sources and unresolved cross-stack dependencies are additional full stops — see
the shared-standards skill for the canonical gate definitions.

## The developer workflow

```
Once per project:   settings.json dependency -> drop SRS + MOMs + design links in docs/specs/ -> /onboard-project
Once per developer: accept plugin install prompt -> authorize Atlassian connector (OAuth); Figma connector when designs live in Figma
Per ticket:         [/research-ticket] -> /create-spec -> review spec -> /implement -> review diff -> PR
```

Human checkpoints: the developer approves the spec (spec approval gate), the
implementation plan (plan gate), and reviews the final diff. Jira access is
read-only; Figma access — used to read design frames behind Figma links — is
read-only through each developer's own Figma connector, and without it agents
request exported frames instead of guessing. All generated artifacts are
committed to the consuming project repo alongside the code they explain.

Two contracts are additionally harness-enforced by safety hooks shipped with the
plugin (see `hooks/`): git write operations (commit/push/tag creation, `gh pr create/merge`)
are denied — the developer commits, never the plugin — and file writes containing
secret-shaped or SSN-shaped values are denied before they reach disk. Test
enforcement is deliberately NOT a hook: the implementer agents own test coverage
(both with a hard rule against weakening tests; the backend agent additionally
never lowers a coverage threshold, adds an exclusion, or deletes a quality-gate
rule), and the consuming project's CI on the pull request is the deterministic
backstop.

## Installation

### Team-wide (recommended)

Commit this once to the consuming project repo:

```json
// .claude/settings.json
{
  "extraKnownMarketplaces": {
    "purandar-ai": {
      "source": { "source": "github", "repo": "AdityaP2024/purandar-agentic-ai" }
    }
  },
  "enabledPlugins": {
    "ai-agent@purandar-ai": true
  }
}
```

Every developer who opens the project in Claude Code is prompted to install the
plugin automatically. Installs use the developer's existing GitHub credentials.

### Manual (trying it out, or personal cross-project use)

```
/plugin marketplace add AdityaP2024/purandar-agentic-ai
/plugin install ai-agent@purandar-ai
```

## Repository structure

```
.claude-plugin/    plugin.json + marketplace.json (this repo is its own marketplace)
agents/            agent definitions (YAML frontmatter: name, description with dispatch
                   examples; tool posture is enforced by each agent's body hard rules)
commands/          slash-command workflows (the orchestration layer)
hooks/             harness-enforced safety hooks (hooks.json + scripts/): git-write
                   guard and secret/PHI write guard, active in every consuming repo
skills/            knowledge layer: shared-standards, hipaa, audit-logging, spring-boot, react
templates/         locked output formats: research, tech-spec, project-brief, decisions log
docs/              agent catalog (AGENT-CATALOG.md) and getting-started guide (GETTING-STARTED.md)
```

Layering rules: **agents** hold persona and hard rules, **skills** hold patterns
and reference knowledge, **commands** hold workflow and orchestration,
**templates** hold locked output contracts. Process never leaks into skills;
knowledge never leaks into commands. The one deliberate exception is
`shared-standards`, which carries the cross-cutting process contracts (gates,
budgets, taxonomies) every agent must obey regardless of which command invoked it.

## Versioning

Semantic versioning via `version` in `.claude-plugin/plugin.json`. Consuming
projects pick up new versions when a developer runs `/plugin marketplace update`
— updates never land silently mid-sprint.

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
- Hook scripts (`hooks/scripts/`) must pass `bash -n`, be executable, fail OPEN when `jq`
  is missing (they are defense-in-depth, never the only line of defense), and never echo
  a matched secret or PHI value back in their block messages.
