<!--
LOCKED TEMPLATE: research.md
Filled by the jira-researcher agent at docs/tickets/<KEY>/research.md in the context repo
(shared-standards Context Root rule).

RULES FOR THE AGENT FILLING THIS TEMPLATE:
- Headings are LOCKED. /create-spec and /implement parse this file by its exact
  headings. NEVER rename, remove, reorder, or add a top-level (##) section.
- Write NONE under any section with nothing to report. NEVER delete the section.
- Replace every {PLACEHOLDER} token with real content. NEVER leave a token in
  the finished file.
- The italic guidance line under each heading states what belongs there and the
  quality bar. Remove guidance lines from the finished file; they are for you,
  not the reader.
- Tables show one placeholder row. Repeat the row per item; delete unused
  placeholder rows.
- Remove this ENTIRE comment block from the finished file.
- Notation: {curly} tokens are values you substitute; <KEY> in rule text stands
  for the ticket key when documenting a path.
-->

# Research: {KEY} — {TITLE}

## Ticket Summary

_Metadata exactly as it appears in Jira at research time. Copy values verbatim; write NONE for any field Jira leaves empty._

| Field | Value |
|---|---|
| Key | {KEY} |
| Title | {TITLE} |
| Type | {TYPE — Story / Bug / Task / Sub-task} |
| Status | {STATUS} |
| Priority | {PRIORITY} |
| Epic | {EPIC_KEY_AND_NAME} |
| Sprint | {SPRINT} |
| Labels | {LABELS} |
| Assignee | {ASSIGNEE} |
| Reporter | {REPORTER} |
| Link | {TICKET_URL} |

## Requirement Narrative

_The synthesized ask after reading ALL sources — not a paraphrase of the description alone. MUST reflect refinements from later comments._

### What

{ONE_TO_THREE_PLAIN_LANGUAGE_SENTENCES_STATING_THE_ASK}

### Why

{BUSINESS_CONTEXT — who needs this, what problem it solves, what happens if it is not done}

## Sources Read

_Every source consumed, in the order read. A source absent from this section was NOT read — list it under Inaccessible Sources instead. NEVER claim a source was read without recording it here._

### Description

{ONE_LINE_SUMMARY_OF_THE_DESCRIPTION_AND_WHAT_IT_ESTABLISHES}

### Comments (chronological)

_All comments, oldest first. Per the shared-standards conflict authority matrix ("Within the Jira ticket itself" row), the LATEST comment overrides earlier comments and the description — mark every comment that changed the requirement and state what changed._

| # | Author | Date | Summary | Changed the requirement? |
|---|---|---|---|---|
| {N} | {AUTHOR} | {DATE} | {WHAT_THE_COMMENT_SAYS} | {NO, or YES — what it overrides or refines} |

### Linked Issues

_Every linked issue, grouped by link type: blocks / is blocked by / relates to / parent-child / duplicates. State what each contributes to or constrains in this ticket._

| Link Type | Key | Title | Status | Relevance to this ticket |
|---|---|---|---|---|
| {blocks / is blocked by / relates to / parent-child / duplicates} | {LINKED_KEY} | {LINKED_TITLE} | {LINKED_STATUS} | {WHY_IT_MATTERS_HERE} |

### Attachments

_Every attachment. Images (screenshots, mockups, diagrams) MUST be read visually, not just listed — record the layout intent they encode (placement, hierarchy, states, spacing, flows). Figma links from the description or comments are rows here too — Type "Figma link", the URL in the Filename column, frames read via the user's Figma connector. Anything that could not be opened or followed moves to Inaccessible Sources (for a Figma link, with the export-frames-as-PNG/PDF request)._

| Filename | Type | Read visually? | Layout intent / content encoded |
|---|---|---|---|
| {FILENAME_OR_FIGMA_URL} | {image / document / Figma link / other} | {YES / N/A} | {WHAT_THE_ATTACHMENT_SPECIFIES} |

## Acceptance Criteria

_Verbatim criteria — quote, do not paraphrase. Every criterion MUST carry a source attribution (description, comment #N, or linked issue key). Note refinements from later comments inline; the refined version is authoritative._

1. "{CRITERION_VERBATIM}" — source: {description / comment #N / linked issue KEY}. {Refined by comment #N: WHAT_CHANGED, or no refinement}

## Conflicts and Clarifications

_Every contradiction between sources (description vs comment, ticket vs attachment, ticket vs linked issue). Resolve per the shared-standards conflict authority matrix and cite the rule applied, or mark OPEN for the developer. Conflict gate: NEVER silently pick a side — an unrecorded resolution is a violation._

| # | Conflict | Sources in tension | Domain | Resolution |
|---|---|---|---|---|
| {N} | {WHAT_CONTRADICTS_WHAT} | {SOURCE_A} vs {SOURCE_B} | {DOMAIN_PER_AUTHORITY_MATRIX} | {RESOLUTION_AND_MATRIX_RULE_APPLIED, or OPEN} |

## Related Code

_Findings from the codebase scan. One line per file/module on why it is relevant. List existing patterns and similar implementations the spec MUST reuse — NEVER invent a new abstraction where an existing one serves._

### Relevant files and modules

| File / Module | Why relevant |
|---|---|
| {REPO_RELATIVE_PATH} | {ONE_LINE_REASON} |

### Patterns and similar implementations to reuse

| Pattern / Prior implementation | Where | Reuse for |
|---|---|---|
| {PATTERN_NAME} | {REPO_RELATIVE_PATH} | {WHAT_PART_OF_THIS_TICKET} |

## Project Context Cross-Check

_Everything in PROJECT_BRIEF.md and docs/decisions.md that bears on this ticket. If PROJECT_BRIEF.md is missing, write NONE and flag that /onboard-project has not been run._

### Applicable business rules, constraints, and glossary terms (PROJECT_BRIEF.md)

| Item | Type | How it applies here |
|---|---|---|
| {RULE_CONSTRAINT_OR_TERM} | {business rule / constraint / glossary term} | {EFFECT_ON_THIS_TICKET} |

### Constraining decisions (docs/decisions.md)

| Decision ID | Decision | Constraint on approach |
|---|---|---|
| {DECISION_ID} | {ONE_LINE_SUMMARY} | {WHAT_IT_RULES_IN_OR_OUT} |

## Scope Split

_Split the work by stack layer so /create-spec can assign it. Out-of-scope items MUST be recorded with attribution — NEVER silently dropped. Backend work assumed done is an out-of-scope row, not an omission._

| Layer | In scope | Notes |
|---|---|---|
| Frontend | {FRONTEND_WORK_OR_NONE} | {NOTES} |
| Backend | {BACKEND_WORK_OR_NONE} | {NOTES} |
| Cross-stack | {API_CONTRACT_OR_SHARED_WORK_OR_NONE} | {NOTES} |

### Out of scope

| Item | Why out of scope | Attribution |
|---|---|---|
| {EXCLUDED_ITEM} | {REASON} | {WHO_OR_WHAT_SOURCE_EXCLUDED_IT — e.g. comment #N, description, assumed done by backend} |

## Compliance Notes

_Assess against the PROJECT_BRIEF.md compliance profile. If the ticket touches PHI or regulated data, every create/read/update/delete/export of that data needs an audit event — list them so /create-spec and /hipaa-check can verify coverage._

Touches PHI or regulated data: {YES / NO — per PROJECT_BRIEF.md compliance profile; state which data}

| Operation | Data touched | Audit event needed |
|---|---|---|
| {OPERATION} | {DATA_CLASS} | {YES — event description / NO — reason} |

## Inaccessible Sources

_Everything that could not be read: unauthorized connector, failed attachment fetch, dead link, permission-denied ticket. State which conclusions in this document are weakened by each gap. Write NONE if every source was readable._

| Source | Why inaccessible | Conclusions weakened |
|---|---|---|
| {SOURCE} | {FAILURE_REASON} | {WHICH_SECTIONS_OR_CLAIMS_REST_ON_PARTIAL_CONTEXT} |

## Open Questions

_Maximum 2 questions for the developer (question budget). Each MUST have enumerated options and a recommended default. Prefer a recorded assumption over a question when the default is safe. Write NONE if nothing needs the developer._

**Q1: {QUESTION}**

- Option A: {OPTION_A}
- Option B: {OPTION_B}
- Recommended default: {OPTION_LETTER — ONE_LINE_RATIONALE}

**Q2: {QUESTION}**

- Option A: {OPTION_A}
- Option B: {OPTION_B}
- Recommended default: {OPTION_LETTER — ONE_LINE_RATIONALE}

## Provenance

_Who produced this document, when, and from what. Fill every field; downstream agents use this to judge staleness against the live ticket._

| Field | Value |
|---|---|
| Generated by | jira-researcher (ai-agent plugin v{PLUGIN_VERSION}) |
| Date | {DATE} |
| Ticket | {TICKET_URL} |
| Inputs used | {INPUTS — e.g. Jira ticket via Atlassian MCP, PROJECT_BRIEF.md, docs/decisions.md, codebase scan} |
