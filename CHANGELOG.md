# Changelog

All notable changes to the ai-agent plugin. Versioning follows semver via
`.claude-plugin/plugin.json`; consuming projects pick up releases with
`/plugin marketplace update`.

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
