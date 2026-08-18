---
name: hipaa
description: read this as the fast PHI/HIPAA check during any code review, code generation, or spec that touches patient or member data — leak prevention, minimum necessary, framework-error-message hygiene, and 42 CFR Part 2 obligations where the project's Compliance Profile flags them
---

# HIPAA / PHI Reference Card

This card is the single source of truth on PHI for every agent (doc-analyst, jira-researcher, spec-writer, frontend-react, backend-springboot, hipaa-compliance). It owns one thing: what must NEVER leak. Audit-logging requirements (what events to record, retention, integrity) live in the `audit-logging` skill — do not restate them here or from memory.

## Project PHI Surface — check first

The rules on this card are universal; WHAT counts as PHI-bearing data in a given repo is not. Before applying these rules, read the **Compliance Profile** section of the repo's `PROJECT_BRIEF.md` (`docs/output-specs/`) — it names the PHI-bearing entities, tables, and DTOs for that project. If `PROJECT_BRIEF.md` or its Compliance Profile is missing or incomplete (including unconfirmed categories), you MUST fail closed: treat ALL person-related data (names, contacts, dates, human-facing identifiers, free-text about a person) as PHI. System-generated surrogate IDs (UUIDs, database PKs) remain safe to log even in fail-closed mode.

## The 18 HIPAA PHI Identifiers (ground truth — never invent others)

Any of these, combined with health information, makes the record PHI:

| #  | Identifier                                              | #  | Identifier                                        |
|----|---------------------------------------------------------|----|---------------------------------------------------|
| 1  | Names                                                   | 10 | Account numbers                                   |
| 2  | Geographic data smaller than state (address, city, ZIP) | 11 | Certificate / license numbers                     |
| 3  | Dates (except year) related to an individual (DOB, admission, discharge, death); all ages over 89 and any date element indicative of such age | 12 | Vehicle identifiers (VIN, license plates) |
| 4  | Phone numbers                                           | 13 | Device identifiers and serial numbers             |
| 5  | Fax numbers                                             | 14 | Web URLs                                          |
| 6  | Email addresses                                         | 15 | IP addresses                                      |
| 7  | Social Security numbers (SSN)                           | 16 | Biometric identifiers (fingerprints, voice)       |
| 8  | Medical record numbers (MRN)                            | 17 | Full-face photographs and comparable images       |
| 9  | Health plan beneficiary numbers                         | 18 | Any other unique identifying number, code, or characteristic |

Rule of thumb: a system-generated surrogate ID (UUID, database PK) is safe to log; anything a human uses to identify a person is not.

## Never-Log List

These field names (and their obvious variants/nestings) MUST NEVER appear in logs, error messages, URLs, analytics events, or exception payloads:

```java
// PHI_FIELDS — never in logs, errors, URLs, analytics, or exception messages
name, firstName, lastName, middleName, maidenName, preferredName,
dateOfBirth, dob, birthDate, admissionDate, dischargeDate, deathDate,
address, street, city, zip, postalCode, county,
phone, phoneNumber, fax, email,
ssn, socialSecurityNumber, mrn, medicalRecordNumber,
memberId, beneficiaryId, policyNumber, accountNumber, licenseNumber,
diagnosis, diagnosisCode, condition, medication, allergy, labResult, clinicalNote,
photo, avatar, biometricData, ipAddress, deviceSerial
```

Free-text fields (notes, comments, descriptions, chief complaint) are presumed to contain PHI. Log their presence or length, never their content.

## Safe Logging — Java / SLF4J

Log surrogate IDs and error codes. NEVER log entity content, and beware `toString()` on entities — Lombok `@Data`/`@ToString` dumps every field.

```java
// VIOLATION: entity toString() serializes every PHI field into the log
log.info("Updating member: {}", member);
// VIOLATION: PHI in log arguments
log.error("Lookup failed for {} dob {}", patient.getLastName(), patient.getDateOfBirth());
// VIOLATION: PHI baked into an exception message — it will surface in logs, traces, and API errors
throw new EntityNotFoundException("No member found with SSN " + ssn);

// CORRECT: surrogate ID + error code only
log.info("Updating member id={}", member.getId());
log.error("Member lookup failed id={} errorCode={}", memberId, ex.getErrorCode());
// CORRECT: generic exception message; the ID goes to the internal log, not the message
log.warn("Member lookup failed id={}", memberId);
throw new EntityNotFoundException("Member not found"); // HIPAA: no identifying data in exception messages
```

Also NEVER: PHI in MDC values echoed to log lines, in `@Slf4j` debug dumps of request/response bodies, or in messages of exceptions that propagate to API error responses.

## Framework Error Messages — They Quote the Payload

The messages you write are only half the surface: messages the framework and its drivers GENERATE embed the data that caused them. Three recurring sources, each a VIOLATION the moment the message reaches an API response, a log line, or an error-reporting payload:

- **JSON parse errors** quote the offending request body — on a PHI API, that is the patient record being submitted.
- **Bean Validation / binding failures** can echo the rejected value in their default messages.
- **Database constraint violations** name the conflicting value (`Key (email)=(jane@example.com) already exists`).

The rule: at every boundary handler (`@ExceptionHandler` methods, advice classes, filter-level error writers), the framework's message is REPLACED with a generic one. `ex.getMessage()` from a parser, validator, or driver never reaches an API response — and is not logged either, unless that exception type provably cannot embed data values. When in doubt, log the exception class and a correlation ID, not the message.

```java
// VIOLATION: the parser message quotes the malformed request body — PHI included
@ExceptionHandler(HttpMessageNotReadableException.class)
ResponseEntity<ApiError> onUnreadable(HttpMessageNotReadableException ex) {
    log.warn("Bad request: {}", ex.getMessage());
    return badRequest(ex.getMessage());
}

// CORRECT: generic message both ways; the payload reaches neither response nor log
@ExceptionHandler(HttpMessageNotReadableException.class)
ResponseEntity<ApiError> onUnreadable(HttpMessageNotReadableException ex) {
    log.warn("Malformed request body requestId={}", requestId); // HIPAA: parser messages quote the payload — never log or return them
    return badRequest("Malformed request body");
}
```

The same discipline applies to any centralized handler the repo already has: a handler that passes framework messages through is a finding even when every message it currently produces happens to be clean — the next malformed payload writes the message.

## Safe Logging — React / TypeScript

NEVER put PHI in `console.*`, `localStorage`/`sessionStorage`, URL query params or route params, third-party analytics, or error-reporting payloads.

```typescript
// VIOLATION: PHI object in console (persists in browser logs and support screenshots)
console.log('loaded patient', patient);
// VIOLATION: PHI in browser storage (unencrypted, survives the session)
localStorage.setItem('currentPatient', JSON.stringify(patient));
// VIOLATION: PHI in the URL — cached in history, proxies, and server access logs
navigate(`/search?lastName=${lastName}&dob=${dob}`);
// VIOLATION: PHI shipped to analytics / error reporting
analytics.track('record_viewed', { memberName: member.name });
errorReporter.captureException(err, { extra: { patient } });

// CORRECT: surrogate IDs only, everywhere client-side state can leak
console.debug('loaded patient', { id: patient.id });
navigate(`/patients/${patient.id}`); // HIPAA: route params carry surrogate IDs only
analytics.track('record_viewed', { entityType: 'member', id: member.id });
errorReporter.captureException(err, { extra: { patientId: patient.id, errorCode } });
```

Keep PHI in in-memory state (component state, query cache) only; it MUST NOT be serialized to storage, URLs, or the network except to the application's own API over TLS.

## Minimum Necessary Checklist

Ask all four before writing or approving any query, endpoint, or fetch that touches PHI:

1. Does this function need ALL the fields it selects, or can it work with a surrogate ID plus status?
2. Is every field returned to the client actually rendered or used?
3. Is access scoped to the records the requesting user is authorized for (their patients/members only)?
4. Could this work with de-identified or aggregated data instead of row-level PHI?

If any answer is "no" or "unknown", narrow the selection before proceeding.

## 42 CFR Part 2 — Substance-Use / Behavioral-Health Records

Applicability is a project fact, not a default. Check the Compliance Profile in `PROJECT_BRIEF.md`: when it marks any data as covered by 42 CFR Part 2 (substance use disorder treatment records — common in behavioral-health projects), the rules below apply ON TOP of everything else on this card, because Part 2 is stricter than HIPAA. When the profile is silent but the project is plainly behavioral-health, raise applicability as an open question to the developer and apply these rules in the interim — never assume Part 2 away.

- **Consent gates disclosure.** Part 2 records leave the system boundary (responses to another organization, exports, outbound integrations) only through a code path that verifies a valid consent covering that recipient and purpose. A disclosure path with no consent check is a VIOLATION; a consent model that cannot express recipient or purpose is a RISK to surface at spec time.
- **Marked and separable.** Part 2 data is distinguishable in the data model — a flag, type, or category the schema actually carries. Consent checks and disclosure accounting are impossible against records that cannot be told apart from general PHI, so a design that mixes them indistinguishably is a spec-time finding.
- **No silent re-disclosure.** Data received under a Part 2 consent is not forwarded onward (downstream integrations, secondary exports), and exports of Part 2 data carry the redisclosure-prohibition notice wherever the format supports one.
- **Disclosures are accounted.** Every Part 2 disclosure emits an audit event — the event taxonomy, retention, and integrity rules live in the `audit-logging` skill (EXPORT events); this card requires only that the disclosure path emits one.

Everything else on this card applies unchanged; treat Part 2 fields as the most sensitive entries of the Never-Log List.

## API Surface Rules

| Rule | Requirement |
|------|-------------|
| Query strings | PHI NEVER in query strings or path segments. Search with PHI criteria MUST use POST with the criteria in the body. |
| Response shaping | Apply field-level filtering (DTO projections) so responses carry only the fields the consuming screen renders — never return the full entity by default. |
| Error responses | Generic messages plus an error code and correlation ID; identifying detail stays in internal logs (by surrogate ID). Framework-generated messages are never passed through — see "Framework Error Messages". |
| Record scoping | A child record fetched under a parent path or parameter MUST be verified to belong to that parent (scoped in the query itself where possible), and every lookup is scoped to the records the requesting user is authorized for — an unscoped child lookup is cross-patient exposure. |
| Examples and tests | NO real or realistic PHI in example payloads, fixtures, seed data, or tests — placeholder IDs and obviously-fake values only (e.g. `member-0001`, `TEST_LASTNAME`). |
| Specs | tech-specs in `docs/tickets/<KEY>/tech-spec.md` MUST mark each PHI-bearing field in request/response tables so implementers inherit the constraint. |

## Compliance as Code Comment

When generating code that touches PHI, embed a `// HIPAA: ...` comment stating the constraint at the exact line it applies, so the rule travels with the pattern through copy-paste and refactors:

```java
log.info("Claim submitted id={}", claim.getId()); // HIPAA: log surrogate ID only, never claim content
```

```typescript
const masked = maskSsn(form.ssn); // HIPAA: render last 4 digits only; full SSN never leaves this handler
```

Use it at every logging call, error construction, storage write, and outbound payload in PHI-touching code paths.

## Severity Taxonomy for Compliance Findings

Report findings in this order (text labels only, never emojis):

| Severity | Meaning | Corrected code |
|----------|---------|----------------|
| VIOLATION | Confirmed PHI exposure (PHI reaches a log, URL, storage, analytics, or error payload) | MANDATORY |
| RISK | Could expose PHI under plausible conditions (e.g. entity `toString()` reachable from a logger, unfiltered DTO) | Recommended |
| BEST-PRACTICE | Compliant but improvable (missing `// HIPAA:` comments, over-broad SELECT that is filtered later) | Optional |

Every compliance report (including `/hipaa-check` output) MUST end with a one-line count: `Findings: N VIOLATION, N RISK, N BEST-PRACTICE`.

## Audit Pointer

This card owns leak prevention only. For audit-logging requirements — which PHI-access events to record, retention periods, and log integrity — load the `audit-logging` skill. If a review needs both, report leak findings under this card's taxonomy and audit gaps under that skill's rules; never merge the two rule sets.
