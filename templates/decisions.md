<!--
SCAFFOLD: decisions.md
Copied verbatim by the doc-analyst agent (launched by /onboard-project) to docs/decisions.md in the
consuming repo. Do not edit this scaffold per-project; all project content is appended in the
consuming repo's copy.
-->

# Decision Log

## Contract

- This file is APPEND-ONLY. NEVER delete or modify a past entry, including typos. To change a
  decision, append a NEW entry and set the old entry's Status to `Superseded by PREFIX-NNN` — that
  Status line is the only permitted edit to an existing entry.
  Exception: the seeded EXAMPLE entry and its Index row are scaffold, not decisions — delete both
  when appending the first real entry.
- Every agent MUST read the Index below before making an architectural choice, and MUST cite
  decision IDs (e.g. "per SHARED-001") when following precedent in research.md, tech-spec.md, or
  code review output.
- Appends are APPROVAL-GATED: the drafting agent returns the entry (plus its Index row) as a
  drafted diff; the launching command in the main session presents it to the developer and appends
  ONLY after explicit approval. Subagents NEVER write this file themselves. NEVER append silently.
- Every append MUST update the Index in the same change. An entry without an Index row is a
  contract violation.
- Entries are capped at ~150 words. Details live in the docs/tickets/<KEY>/tech-spec.md or
  docs/tickets/<KEY>/research.md the entry points to — the log records WHAT was decided and WHY,
  not the full design.

## Index

<!-- One line per decision, newest last. MUST be updated with every append.
     Delete the EXAMPLE row together with the example entry below. -->

| ID | Date | Title | Status |
|---|---|---|---|
| SHARED-001 | 2026-01-15 | Adopt a standard REST error envelope (EXAMPLE) | Accepted |

## ID Namespaces

| Prefix | Scope | Typically Authored By |
|---|---|---|
| BE- | Backend-only decisions | backend-springboot |
| FE- | Frontend-only decisions | frontend-react |
| SHARED- | Cross-cutting decisions affecting more than one domain | any agent |

- IDs are sequential PER NAMESPACE: BE-001, BE-002, ... FE-001, ... SHARED-001, ... Never reuse or
  renumber an ID.
- Cross-team decisions are OWNED by a SHARED- entry. BE-/FE- entries reference the SHARED- ID and
  NEVER restate its content — one decision, one source of truth.

## Entry Template

Copy this template verbatim for every new entry. Write NONE in fields that do not apply.

```markdown
## [PREFIX-NNN] {Title}

- Date: {YYYY-MM-DD}
- Author: {developer} + {agent}
- Status: Accepted | Superseded by PREFIX-NNN
- Jira: {TICKET-KEY, or NONE if not ticket-driven}
- Context: {what forced a choice — 1-3 sentences}
- Decision: {what was decided — 1-3 sentences}
- Consequences: {what this binds future work to — 1-3 sentences}
- Extends / Supersedes: {IDs this builds on or replaces, or NONE}
```

---

<!-- EXAMPLE ENTRY: delete this entry AND its Index row after appending the first real decision. -->

## [SHARED-001] Adopt a standard REST error envelope

**EXAMPLE — delete after the first real entry is appended.**

- Date: 2026-01-15
- Author: A. Developer + spec-writer
- Status: Accepted
- Jira: NONE
- Context: Endpoints returned errors in inconsistent shapes (bare strings, framework defaults),
  so the frontend could not handle failures uniformly and error contracts were re-invented per
  ticket.
- Decision: All REST endpoints return errors as `{ "error": { "code": string, "message": string,
  "details": array } }`. `code` is a stable machine-readable identifier; `message` is
  human-readable and MUST NOT be parsed by clients.
- Consequences: Backend routes all exceptions through one shared handler producing this envelope.
  Frontend error handling branches on `error.code` only. Every tech-spec's error-mapping table uses
  this shape. New endpoints deviating from it are a BREAKING review finding.
- Extends / Supersedes: NONE
