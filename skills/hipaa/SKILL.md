---
name: hipaa
description: read this as the fast PHI/HIPAA check during any code review, code generation, or spec that touches patient or member data
---

# HIPAA / PHI Reference Card

This card is the single source of truth on PHI for every agent (doc-analyst, jira-researcher, spec-writer, frontend-react, backend-springboot, hipaa-compliance). It owns one thing: what must NEVER leak. Audit-logging requirements (what events to record, retention, integrity) live in the `audit-logging` skill — do not restate them here or from memory.

## Project PHI Surface — check first

The rules on this card are universal; WHAT counts as PHI-bearing data in a given repo is not. Before applying these rules, read the **Compliance Profile** section of the repo's `PROJECT_BRIEF.md` (repo root) — it names the PHI-bearing entities, tables, and DTOs for that project. If `PROJECT_BRIEF.md` or its Compliance Profile is missing or incomplete (including unconfirmed categories), you MUST fail closed: treat ALL person-related data (names, contacts, dates, human-facing identifiers, free-text about a person) as PHI. System-generated surrogate IDs (UUIDs, database PKs) remain safe to log even in fail-closed mode.

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

## API Surface Rules

| Rule | Requirement |
|------|-------------|
| Query strings | PHI NEVER in query strings or path segments. Search with PHI criteria MUST use POST with the criteria in the body. |
| Response shaping | Apply field-level filtering (DTO projections) so responses carry only the fields the consuming screen renders — never return the full entity by default. |
| Error responses | Generic messages plus an error code and correlation ID; identifying detail stays in internal logs (by surrogate ID). |
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
