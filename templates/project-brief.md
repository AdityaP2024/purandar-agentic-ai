<!--
LOCKED TEMPLATE: PROJECT_BRIEF.md
Filled in by doc-analyst during /onboard-project and written to the CONSUMING REPO ROOT as PROJECT_BRIEF.md.

RULES FOR ALL AGENTS AND FOR doc-analyst:
- Headings are LOCKED. Every agent (jira-researcher, spec-writer, frontend-react, backend-springboot,
  hipaa-compliance) locates content by these exact headings. NEVER rename, reorder, remove, or add
  numbered sections.
- If a section has no content, write NONE. NEVER leave a section blank and NEVER delete it.
- This brief is the distilled SRS. Agents read this file for cheap context and open the originals in
  docs/specs/ ONLY when chapter-level detail is needed (see Section 9, Document Index).
- Regenerate when the SRS in docs/specs/ changes materially, OR to update the "Where Implemented"
  column in Section 3 as implementations are located. Both paths require doc-analyst to show the
  developer a diff against the current file and WAIT for approval before overwriting.
- {curly-brace} placeholders and per-section comments are fill instructions for doc-analyst; replace
  or remove them in the generated file.
- Remove this ENTIRE comment block from the generated file. The heading-lock and regeneration rules
  live in this template and in the doc-analyst agent, not in the generated brief.
-->

# PROJECT_BRIEF

## 1. Project Overview

<!-- doc-analyst: 5-10 lines. What the system does, for whom, and the primary business outcome.
     No feature lists, no architecture — an agent reading only this section must be able to state
     the system's purpose in one sentence. -->

{5-10 lines: what the system does, who uses it, why it exists}

## 2. Domain Glossary

<!-- doc-analyst: business terms developers and agents will meet in Jira tickets. Include synonyms
     and abbreviations. One row per term; keep definitions to one sentence. -->

| Term | Definition | SRS Source Section |
|---|---|---|
| {term} | {one-sentence definition} | {docs/specs/ document, section number} |

## 3. Core Entities and Relationships

This is the CANONICAL entity mapping for this repository. Agents MUST consult this table before
proposing any new entity, table, service, or endpoint.

<!-- doc-analyst: one row per business entity from the SRS. Fill "Where Implemented" as modules are
     discovered; write "not yet located" until confirmed. Agents that discover an implementation
     location update the column via the regeneration flow (diff + approval). -->

| Entity | Key Attributes | Relationships | Where Implemented (module/package) |
|---|---|---|---|
| {entity} | {2-5 defining attributes} | {relationship -> other entity, cardinality} | {module/package, or "not yet located"} |

### How agents must apply this

1. Extract the entity nouns from each acceptance criterion (AC) in the ticket. Normalize synonyms
   using the Domain Glossary (Section 2).
2. Look each noun up in the table above.
3. If the entity exists, confirm whether the existing implementation (Where Implemented column)
   already covers the AC. Record the finding in docs/tickets/<KEY>/research.md as either
   "existing implementation covers this AC" or a named gap.
4. Only when this table and the located code genuinely do not cover the requirement, propose new
   work: classify the AC as BACKEND-REQUIRED or CROSS-STACK in tech-spec Section 2, and record any
   new entity in tech-spec Section 6 (Data Model Changes).

Rule of thumb: prove reuse does not exist before proposing new code.

## 4. Business Rules and Constraints

<!-- doc-analyst: number sequentially. On regeneration NEVER renumber or delete existing rules — a
     rule removed from the SRS keeps its ID with the Rule cell marked "RETIRED — removed in
     {document, version/date}". One row per rule. Agents MUST cite BR numbers when a spec or
     implementation choice enforces a rule. -->

| ID | Rule | SRS Source Section |
|---|---|---|
| BR-1 | {rule stated as a testable constraint} | {docs/specs/ document, section number} |
| BR-2 | {rule} | {source} |

## 5. Compliance Profile

<!-- doc-analyst: list ONLY the PHI/regulated data that actually flows through THIS system. The
     hipaa-compliance agent and /hipaa-check apply their rules to whatever is listed here — an
     overbroad list creates noise, an incomplete one creates exposure. -->

| Data Category | Classification (PHI / PII / regulated / none) | Flows Through (modules, integrations) | Retention Constraint |
|---|---|---|---|
| {data category} | {classification} | {where it enters, is stored, and leaves} | {retention rule or NONE} |

- BAA context: {which parties hold a BAA covering this system, or NONE}
- Retention constraints: {summary of legal/contractual retention rules, or NONE}

FAIL-CLOSED RULE: if this section is blank, incomplete, or lists unconfirmed categories, all agents
MUST treat all person-related data in this system as PHI and apply the full hipaa skill rule set
until a developer completes it. A verified absence of regulated data is recorded as exactly:
"NONE — confirmed by complete SRS read on {YYYY-MM-DD}: no PHI/PII/regulated data flows through
this system". Only that confirmed form lifts the fail-closed default; a bare NONE does not.

## 6. Module Map

<!-- doc-analyst: one row per top-level module/directory. "Work usually lands here" tells an
     implementer where a typical ticket's changes belong. -->

| Module / Directory | Responsibility | Work Usually Lands Here |
|---|---|---|
| {path} | {one-sentence responsibility} | {typical change types that belong here, or "rarely"} |

### NEVER-EDIT-LIGHTLY

Agents MUST NOT modify the following without explicit developer approval at the plan gate:

- Build files ({e.g. pom.xml, build.gradle, package.json — list the actual files})
- Generated code ({list generated directories, or NONE})
- Migration history ({migration directory — append new migrations only, NEVER edit applied ones})
- {other discovered items, or NONE}

## 7. Stack Summary

STALENESS WARNING: this table is a snapshot discovered from build files at onboarding time. It may
be stale. Verify against pom.xml / build.gradle / package.json at task time before relying on it.
NEVER pin library versions in specs from this table alone.

<!-- doc-analyst: discover from build files, do not infer from code style. Record the source file
     for each row so agents know where to re-verify. -->

| Layer | Technology | Discovered From |
|---|---|---|
| {e.g. backend framework} | {technology and major version as found} | {build file path} |

## 8. Integration Points

<!-- doc-analyst: every external system this repo calls or is called by. -->

| External System | Purpose | Protocol | Auth Model | Notes |
|---|---|---|---|---|
| {system} | {why we talk to it} | {REST / SOAP / messaging / file / other} | {OAuth2 / API key / mTLS / other} | {rate limits, environments, contacts doc} |

## 9. Document Index

<!-- doc-analyst: one row per document in docs/specs/. "When to deep-dive" tells an agent when this
     brief is not enough and the original must be opened. -->

| Document (docs/specs/) | What It Covers | When to Deep-Dive |
|---|---|---|
| {filename} | {one-sentence scope} | {trigger, e.g. "ticket touches billing calculations"} |

## 10. Provenance

- Generated from: {list of docs/specs/ documents with version/date identifiers}
- Generated on: {YYYY-MM-DD}
- Generated by: doc-analyst (ai-agent plugin v{PLUGIN_VERSION}) via /onboard-project
- Last material SRS change reflected: {document + date, or "initial onboarding"}
