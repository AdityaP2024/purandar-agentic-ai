<!--
LOCKED TEMPLATE — docs/tickets/<KEY>/tech-spec.md
==================================================================
RULES FOR EVERY AGENT AND EVERY EDIT. This comment block MUST stay at the
top of every filled spec. NEVER delete it.

1. HEADINGS ARE LOCKED. /implement parses this document by its numbered
   section headings. NEVER rename, renumber, reorder, remove, or add
   top-level sections. If a section does not apply, keep the heading and
   write NONE under it. An empty section body is a defect; NONE is not.

2. SPEC APPROVAL GATE. The developer MUST approve this spec before
   /implement runs. Approval means the developer flips the Approval Status
   line in Section 13 from DRAFT to "APPROVED by {name} on {YYYY-MM-DD}"
   (that exact form). /implement MUST refuse to proceed while the status
   is DRAFT.

3. OVERWRITE POLICY. If docs/tickets/<KEY>/tech-spec.md already exists,
   spec-writer MUST show the developer a diff between the existing spec and
   the proposed replacement and wait for explicit approval before writing.
   NEVER silently overwrite an existing spec.

4. SUPERSESSION. Supersession is a NEW ticket's spec replacing a
   DIFFERENT ticket's spec (cross-key) — regenerating the SAME ticket's
   spec is the overwrite flow (Rule 3), not supersession. A superseded
   spec is NEVER deleted. Prepend this banner above this comment block
   and update the supersession chain in Section 13 of both documents:

   > SUPERSEDED on {YYYY-MM-DD}. Replaced by: {path or identifier of the
   > replacement spec}. Do NOT implement from this document.

5. FILL MARKERS. Every "FILL:" comment below is an instruction to
   spec-writer. Replace it with real content and delete the comment. A
   finished spec contains no FILL comments and no {placeholder} braces
   anywhere OUTSIDE this top comment block. This top comment block is the
   one comment that MUST remain, braces and all. Notation: {curly} tokens
   are values an agent substitutes; <KEY> in rule text stands for the
   ticket key when documenting a path.

6. CONTENT RULES. No emojis — text labels only. No PHI, no real
   credentials, no realistic-looking secrets in any example payload, curl,
   or fixture — placeholder IDs only (for example PATIENT-PLACEHOLDER-1).
   No pinned library versions and no absolute filesystem paths — name
   tools, files, and conventions exactly as they exist in the consuming
   repo, using repo-relative paths.
-->

# Tech Spec: {KEY} — {TITLE}

## 1. Ticket Brief

| Field | Value |
|---|---|
| Ticket | {KEY} |
| Title | {verbatim Jira summary} |
| Research | {docs/tickets/{KEY}/research.md — OR — "No research.md; inline lightweight research performed on {YYYY-MM-DD} (sources listed in Section 13)."} |

<!-- FILL: One paragraph, max 6 sentences: what this ticket changes, for
whom, and why now. Plain statement of the user-visible outcome. Do not
restate acceptance criteria here — Section 2 owns those verbatim. -->

{summary paragraph}

## 2. AC Coverage Mapping

THE DEFAULT ANSWER IS REUSE. Before classifying any AC as needing new
code, spec-writer MUST search the consuming repo and prove existing code
does not already cover it. The How column MUST name the files, endpoints,
or components inspected — for reused code, what covers the AC; for new
code, what was searched and found missing.

Coverage values (use exactly these labels):

| Label | Meaning |
|---|---|
| EXISTING | Existing code already satisfies this AC. No new work. |
| FRONTEND-ONLY | Satisfiable entirely in the frontend app against existing APIs. |
| BACKEND-REQUIRED | Needs a new or changed backend endpoint, service, or schema. |
| CROSS-STACK | Needs coordinated frontend and backend work. MUST have a row in Section 7. |

<!-- FILL: One row per acceptance criterion, in ticket order. The
Acceptance Criterion column is VERBATIM from Jira — never paraphrase,
never merge, never drop an AC. Every BACKEND-REQUIRED or CROSS-STACK row
MUST trace to Section 5 (API changes) and/or Section 6 (data model
changes) — a row tracing to neither is a defect. Every CROSS-STACK row
MUST also produce at least one row in Section 7.
ZERO-AC TICKETS: if the ticket carries NO acceptance criteria, spec-writer
derives candidate ACs from the description and latest comments; the AC #
column reads "D1 (SPEC-WRITER-DERIVED)", the criterion column carries the
derived wording, and the How column names its source (description /
comment #N). The developer confirms, edits, or deletes derived rows at the
spec approval gate before flipping the status. -->

| AC # | Acceptance Criterion (verbatim) | Coverage | How |
|---|---|---|---|
| AC1 | {verbatim text} | {label} | {evidence: files/endpoints/components inspected; reuse found or proven absent} |

## 3. Approach

<!-- FILL: The chosen design in prose. Cover: end-to-end request flow,
which layers change (backend controller / service / repository; frontend
feature / component), and why this shape. Cite decision-log entries from docs/decisions.md by ID
(for example [BE-012]) wherever precedent applies — follow precedent or
state explicitly why this ticket departs from it. -->

{chosen design}

### Alternatives Considered

<!-- FILL: At least one genuine alternative unless the change is trivially
single-path — then write NONE with one sentence saying why no alternative
exists. -->

| Alternative | Why Rejected |
|---|---|
| {alternative} | {reason} |

### Decision Log Citations

<!-- FILL: IDs from docs/decisions.md that constrain or support this
design, with one line each on how they apply. NONE if no entry applies. -->

| ID | How It Applies |
|---|---|
| {ID} | {application} |

## 4. Affected Components

<!-- FILL: Every file or module /implement will touch. Repo-relative
paths, named per the consuming repo's actual layout. Change Type is
exactly "create" or "modify" — deletions and renames are "modify" with the
detail in Purpose. -->

| File / Module | Change Type | Purpose |
|---|---|---|
| {repo-relative path} | {create OR modify} | {one line} |

## 5. API Contract

THIS SECTION IS DROP-IN. Implementers (frontend-react, backend-springboot)
use it verbatim — no inference, no renaming, no reshaping. If an element
is missing or ambiguous, the implementer STOPS and surfaces the gap to the
developer; it NEVER fills the gap by guessing.

Write NONE here if this ticket changes no API. Otherwise repeat the block
below once per operation. All six elements (a)–(f) are mandatory in every
block — an operation missing any element fails the spec approval gate.

PHI MARKING: every PHI-bearing field in (b), (c), and (f) — per the hipaa
skill and the PROJECT_BRIEF.md Compliance Profile — carries the marker
"PHI" at the end of its annotation, for example:
"lastName": "string — required, max 100, PHI". Implementers inherit the
constraint from that marker.

### Operation: {VerbResource, for example CreateReferral}

**(a) Endpoint signature**

| Method | Path | Auth Requirement |
|---|---|---|
| {GET/POST/PUT/PATCH/DELETE} | {/api/...} | {required role/authority/permission, or "authenticated", or "public" with justification} |

**(b) Request shape**

<!-- FILL: Annotate every field with type, required/optional, and
validation rules (max length, format, allowed values). These rules bind
both Bean Validation on the backend and form validation on the frontend.
For GET/DELETE, document path and query parameters in the same style. -->

```json
{
  "fieldName": "string — required, max 255, non-blank",
  "otherField": "integer — optional, min 0"
}
```

**(c) Success response**

Status: {2xx code}

```json
{
  "id": "string — server-generated identifier",
  "fieldName": "string — echoes request value"
}
```

**(d) Error mapping**

<!-- FILL: One row per error condition the backend can return. Frontend
Handling is exactly one of: INLINE-FORM-ERROR (field-level validation),
TOAST (non-field failure the user must see), REDIRECT (auth expiry or
missing permission — name the destination), RETRY (transient failure —
state the retry policy, then the fallback handling). -->

| Status | Error Condition | Response Body Shape | Frontend Handling |
|---|---|---|---|
| 400 | {validation failure} | {error body shape, per the project's error convention} | INLINE-FORM-ERROR — {which field(s)} |
| 401 | {session expired} | {shape} | REDIRECT — {destination} |
| 403 | {missing permission} | {shape} | {TOAST or REDIRECT} — {detail} |
| 409 | {conflict condition} | {shape} | {handling} |
| 5xx | {server failure} | {shape} | RETRY — {policy}, then TOAST |

**(e) Frontend consumption**

NAMES BELOW MUST FOLLOW THE CONSUMING PROJECT'S OWN CONVENTIONS — discover
the existing service-layer layout, hook naming, and cache-key scheme from
its code. NEVER invent a parallel convention.

| Item | Value |
|---|---|
| Service function | {name and repo-relative file path} |
| Hook | {name and repo-relative file path} |
| Cache keys read | {keys per the project's key scheme, or N/A} |
| Cache keys invalidated on success | {keys, or N/A} |

**(f) Field bindings**

<!-- FILL: One row per form field this operation carries. Transform names
the exact conversion (for example "date -> ISO-8601 string", "trim
whitespace", "none"). -->

| Form Field | API Request Path | Entity / Column | Transform |
|---|---|---|---|
| {field} | {json.path} | {Entity.field / table.column} | {transform or none} |

## 6. Data Model Changes

Write NONE if this ticket changes no entity, table, or column.

Schema changes MUST ship as a migration file using the consuming repo's
migration tool (discover it from the build configuration). NEVER edit the
schema directly, and NEVER edit an already-applied migration.

<!-- FILL: Every entity/table/column change with types and constraints. -->

| Entity / Table | Column | Type | Constraints |
|---|---|---|---|
| {name} | {column} | {type} | {NOT NULL, UNIQUE, FK -> table.column, default, ...} |

**Migration note:** {migration file name per the project's convention, and
what it does — including backfill or data-correction steps if any}

**Indexes:**

| Table | Index | Columns | Rationale |
|---|---|---|---|
| {table} | {name} | {columns} | {query it serves} |

## 7. Cross-Stack Dependencies

HARD GATE. If this section lists ANY item with Status UNRESOLVED,
dependent work STOPS and the implementer surfaces the blocker to the
developer. Implementers NEVER invent workarounds — no mocked endpoints, no
stub responses, no temporary schemas, no "implement against the spec and
hope". The gate lifts only when the developer marks the item RESOLVED.

Write NONE if neither side is blocked on the other.

<!-- FILL: One row per item one side needs from the other, for example
"frontend blocked on new POST /api/referrals endpoint". Every CROSS-STACK
row in Section 2 MUST produce at least one row here. Status is exactly
UNRESOLVED or RESOLVED. -->

| # | Blocked Side | Needs | From | Status |
|---|---|---|---|---|
| 1 | {frontend OR backend} | {exact item, for example endpoint from Section 5 Operation name} | {backend OR frontend OR external team} | {UNRESOLVED OR RESOLVED} |

## 8. Security and Compliance

Write NONE — with one sentence of justification — only if this change
touches no PHI and no other regulated data. If in doubt, do not write
NONE; list the touchpoints and let /hipaa-check and the hipaa-compliance
agent judge.

**PHI touchpoints**

<!-- FILL: Every field and operation in this spec that reads, writes,
displays, or transmits PHI or regulated data. -->

| Field / Operation | Data Class | Touchpoint (read/write/display/transmit) |
|---|---|---|
| {field or operation} | {PHI category or regulated class} | {touchpoint} |

**Audit events**

<!-- FILL: Every audit event this change MUST emit, typed per the
audit-logging skill's taxonomy. Every PHI touchpoint above MUST map to at
least one event or carry an explicit justification for why not. If the
audit-logging skill does not exist in this plugin version, describe each
event (what is recorded, when, for whom) and note in the Event Type
column: "typed per the audit-logging skill's taxonomy once available" —
never fabricate taxonomy names. -->

| Event Type | Category | Emitted When |
|---|---|---|
| {type per audit-logging skill} | {category per audit-logging skill} | {trigger} |

**Authorization requirements**

<!-- FILL: Role/authority checks per operation, and where they are
enforced (method security, endpoint security config, service layer).
MUST agree with element (a) of each Section 5 operation. -->

{requirements}

**Input validation notes**

<!-- FILL: Validation beyond Section 5(b) field rules: cross-field rules,
size limits, content-type restrictions, injection surfaces. NONE if
Section 5(b) covers everything. -->

{notes}

## 9. Edge Cases

<!-- FILL: Enumerate every edge case with its expected behavior. Cover at
minimum: empty/absent inputs, boundary values from Section 5(b) rules,
concurrent modification, permission-denied mid-flow, and partial failure
across Section 7 seams. NONE only for pure-refactor tickets with no
behavior change. -->

| # | Edge Case | Expected Behavior |
|---|---|---|
| 1 | {case} | {behavior} |

## 10. Test Plan

TEST DATA RULE: NO PHI in any fixture, factory, or assertion — placeholder
IDs and synthetic values only.

<!-- FILL: Every AC from Section 2 MUST appear in the coverage table at
least once. State what each level covers for this ticket; write NONE for a
level with a one-line reason if it genuinely does not apply. -->

**Unit:** {what is unit-tested: services, validators, transforms, hooks}

**Integration:** {what is integration-tested: controller-to-database paths, error mapping from Section 5(d), migrations}

**E2E:** {user flows exercised end to end, or NONE with reason}

**AC coverage**

| AC # | Level(s) | Test Description |
|---|---|---|
| AC1 | {unit / integration / e2e} | {what the test proves} |

## 11. Out of Scope and Assumptions

NOTHING IS SILENTLY DROPPED. Anything mentioned in the ticket, comments,
or research that this spec does not implement MUST appear here with
attribution. Every assumption MUST name who asserted it — spec-writer
assumptions are allowed but MUST be labeled as such so the developer can
veto them at the approval gate.

**Out of scope**

| Item | Why Out of Scope | Attribution |
|---|---|---|
| {item} | {reason} | {Jira comment by {name} on {date} / developer instruction / spec-writer judgment} |

**Assumptions**

| Assumption | Attribution |
|---|---|
| {assumption} | {source, or "spec-writer assumption — unverified"} |

## 12. Open Questions

MAX 2 QUESTIONS. Each MUST offer enumerated options and a recommended
default. An APPROVED spec MUST read NONE here: at the spec approval gate
the DEVELOPER resolves each question, folds the resolution into Section 3
(or directs a spec regeneration), sets this section to NONE, and only
then flips the status to APPROVED.

<!-- FILL: NONE, or at most two blocks in this form. -->

**Q1: {question}**

| Option | Description |
|---|---|
| A | {option} |
| B | {option} |

Recommended default: {A or B} — {one-line reason}.

## 13. Provenance

<!-- FILL: All fields. The Approval Status line is the spec approval gate:
spec-writer writes exactly DRAFT; only the developer flips it to
"APPROVED by {name} on {YYYY-MM-DD}" (see Rule 2 in the top comment
block). /implement MUST check this line before doing anything else. -->

| Field | Value |
|---|---|
| Generated by | spec-writer (ai-agent plugin v{PLUGIN_VERSION}) |
| Generated on | {YYYY-MM-DD} |
| Research input | {docs/tickets/{KEY}/research.md — OR — "inline lightweight research; sources: {list}"} |
| Approval Status | DRAFT |
| Inaccessible sources | NONE {or the list carried from research.md / inline research, with the sections it weakens} |
| Supersedes | NONE {or path/identifier of the spec this one replaces} |
| Superseded by | NONE {or path/identifier of the replacement, added when the banner is prepended} |
