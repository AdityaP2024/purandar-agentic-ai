---
name: audit-logging
description: read when a change touches PHI access, adds or changes endpoints that read or write regulated data, or a ticket mentions audit trails or accounting of disclosures
---

# HIPAA Audit Logging Reference Card

This card owns audit requirements: which events to record, the data model, integrity, retention, and the Spring implementation pattern. Leak prevention — what must NEVER appear in any log — is owned by the `hipaa` skill; consult it for the never-log list and report leak findings under its taxonomy. Never merge the two rule sets.

Severity labels, report format, and the one-line count summary (`Findings: N VIOLATION, N RISK, N BEST-PRACTICE`) come from `shared-standards`. Stack facts (framework version, migration tool, package layout, DB user names) are discovered from the consuming repo's build files and migrations at task time — never assumed. Placeholders here (`com.{org}.audit`, `{app_user}`, `{EXTERNAL_SYSTEM}`) are replaced with the repo's real values.

## Regulatory Floor

Every audit design decision traces to one of these. Anything beyond this table is scope creep unless compliance explicitly demands it (see Scope Guardrail).

| HIPAA citation | What it demands | How the pattern satisfies it |
|---|---|---|
| 164.312(b) Audit Controls | Record who did what with PHI, and when | Append-only `audit_log` table + `@Audited` capture + explicit auth hooks |
| 164.528 Accounting of Disclosures | Patient can request an accounting of disclosures of their PHI — the audit trail is what answers that request | Admin endpoint querying `audit_log` by `patient_uuid` over a date range |
| 164.312(c)(1) Integrity | Audit records cannot be silently altered | DB-level `REVOKE UPDATE, DELETE` from the app user — one statement |
| 164.308(a)(1)(ii)(D) Activity Review | Someone reviews the audit trail regularly | Operational control: document that the compliance officer runs the admin endpoint on a schedule |
| 164.316 Retention | 6 years is the federal documentation floor — verify the actual retention period with the org's compliance officer (state law can require longer) | Never delete rows; archive via DB backups; no DELETE-by-age jobs |

## Event Taxonomy

Every event type is a string constant, grouped into exactly four categories. Constants live in per-module `AuditCatalog` classes (one catalog per service/module, e.g. `{Module}AuditCatalog`), never inline strings.

**AUTH** — captured via explicit hooks, never `@Audited`:
- `LOGIN_SUCCESS`, `LOGIN_FAILURE`, `LOGOUT`
- `MFA_CHALLENGE_ISSUED`, `MFA_SUCCESS`, `MFA_FAILURE`
- `PASSWORD_CHANGED`, `PASSWORD_RESET_REQUESTED`

**PHI_READ** — captured via `@Audited`. Missing READ logging is the #1 HIPAA gap; non-healthcare habits skip it reflexively:
- `{ENTITY}_VIEWED`, `{ENTITY}_SEARCHED`, `{ENTITY}_LIST_VIEWED`
- `DOCUMENT_DOWNLOADED`

**PHI_WRITE** — captured via `@Audited`:
- `{ENTITY}_CREATED`, `{ENTITY}_UPDATED`, `{ENTITY}_ARCHIVED`, `{ENTITY}_MERGED`, `{ENTITY}_SIGNED`
- `DOCUMENT_UPLOADED`, `DOCUMENT_DELETED`

**EXPORT** — anything leaving the org is a HIPAA disclosure and MUST be captured. Bulk exports are the #1 disclosure risk. Log capability transfer even if the download never happens:
- `REPORT_EXPORTED`
- `EMAIL_SENT_WITH_PHI`, `FAX_SENT`, `SMS_SENT`
- `{EXTERNAL_SYSTEM}_CLAIM_SUBMITTED`, `{EXTERNAL_SYSTEM}_SYNC_OUT`, `{EXTERNAL_SYSTEM}_SYNC_IN`
- `PRESIGNED_URL_ISSUED`

## Canonical Data Model

Single flat append-only table. Adapt naming to the repo's conventions; the shape is fixed.

```sql
CREATE TABLE audit_log (
    uuid            UUID PRIMARY KEY,
    event_type      VARCHAR(100) NOT NULL,
    event_category  VARCHAR(20)  NOT NULL,  -- AUTH | PHI_READ | PHI_WRITE | EXPORT
    action          VARCHAR(1)   NOT NULL,  -- C | R | U | D | E
    outcome         VARCHAR(20)  NOT NULL,  -- SUCCESS | FAILURE
    outcome_reason  VARCHAR(500),
    recorded_at     TIMESTAMPTZ  NOT NULL,  -- set at EVENT TIME in UTC by the app;
                                            -- never the local clock, never a DB default
    actor_iam_id    VARCHAR(64),            -- IdP subject claim; NULL for failed logins / SYSTEM
    actor_username  VARCHAR(255),
    actor_role      VARCHAR(64),
    source_service  VARCHAR(32)  NOT NULL,
    source_endpoint VARCHAR(500),
    patient_id      BIGINT,
    patient_uuid    UUID,                   -- the cross-service accounting-of-disclosures key
    resource_type   VARCHAR(100),
    resource_id     VARCHAR(128),
    remote_ip       INET,
    payload         JSONB
);

CREATE INDEX idx_audit_log_patient_time ON audit_log (patient_uuid, recorded_at DESC);
CREATE INDEX idx_audit_log_actor_time   ON audit_log (actor_iam_id, recorded_at DESC);
CREATE INDEX idx_audit_log_type_time    ON audit_log (event_type, recorded_at DESC);
CREATE INDEX idx_audit_log_recorded_at  ON audit_log (recorded_at);

-- HIPAA 164.312(c)(1) integrity: the application user cannot alter history
REVOKE UPDATE, DELETE ON audit_log FROM {app_user};
GRANT  SELECT, INSERT ON audit_log TO   {app_user};
```

Types are shown in PostgreSQL terms — map each to the discovered engine's equivalent (timestamp-with-timezone, JSON, string IP); the COLUMN SET and constraints are what is fixed.

Scale consideration: at clinical volume a single hot table degrades and the `recorded_at` index alone will not save the accounting query. Plan time-based partitioning (e.g. Postgres range partitions on `recorded_at`) before the table grows large; it does not change the pattern.

## Payload Rules

`payload` is a sanitized JSON escape hatch, nothing more:

- Allowed: filter scope, row count, sanitized request params (scalar values only), before/after diff summary as FIELD NAMES changed — never field values.
- Truncate every string value to 200 chars to bound row size.
- Bulk exports ALWAYS populate `payload.filterScope` and `payload.rowCount`.
- NEVER passwords, tokens, or full request bodies — that creates a secondary secret store you did not plan for.
- NEVER clinical free-text (notes, observations, diagnostic narratives) — see the `hipaa` skill for the full never-log list.

## The 7-Component Spring Pattern

Every implementation gets exactly these seven pieces, named per the repo's conventions. Capture happens at the SERVICE layer, not the controller layer, so background jobs, queue consumers, and batch processors are covered by the same annotation.

### 1. `@Audited` annotation

```java
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface Audited {
    String eventType();                             // constant from the module's AuditCatalog
    AuditEventCategory category();                  // AUTH | PHI_READ | PHI_WRITE | EXPORT
    AuditAction action() default AuditAction.R;     // C | R | U | D | E
    String resourceType() default "";
    String resourceIdExpression() default "";       // SpEL: "#argName" or "#result.uuid"
    String patientIdExpression() default "";        // SpEL yielding the patient UUID
    boolean includePayload() default false;
}
```

### 2. `@Around` aspect — the capture layer

```java
@Around("@annotation(audited)")
public Object auditMethod(ProceedingJoinPoint jp, Audited audited) throws Throwable {
    Object result = null; Throwable thrown = null;
    try { result = jp.proceed(); return result; }
    catch (Throwable t) { thrown = t; throw t; }        // FAILURE event still emits; original rethrows
    finally {
        try { emitEvent(jp, audited, result, thrown); } // outcome = thrown == null ? SUCCESS : FAILURE
        catch (RuntimeException auditEx) {
            if (thrown == null && failClosed) throw auditEx; // business call succeeded: fail-closed rolls it back
            log.error("Audit emission failed for {}", jp.getSignature(), auditEx);
        }                                               // business exception in flight: NEVER mask it with an audit exception
    }
}
```

Invariants: the failure path emits with `outcome = FAILURE` plus a truncated reason, then the original exception rethrows — a business exception already in flight is never masked by an audit exception; the audit failure is swallowed and logged. When the business call succeeded (`thrown == null`) and fail-closed is active, the audit exception RETHROWS from the aspect so the business transaction rolls back — and for that rollback to take effect, the aspect must sit INSIDE the business transaction boundary (the transaction advice runs outer, the audit aspect inner). SpEL errors degrade gracefully — a bad expression yields null fields, the row still writes. SpEL parameter binding needs the `-parameters` javac flag; the Spring Boot parent sets it, verify in the repo's build file otherwise.

### 3. `AuditLogService` — the single write seam

```java
@Transactional(propagation = Propagation.REQUIRES_NEW)  // FAILURE events survive business-tx rollback
public void log(AuditEvent event) {
    try { repo.save(toEntity(event)); }                 // toEntity sets recordedAt = Instant.now() (UTC)
    catch (RuntimeException ex) {
        if (failClosed) throw ex;                       // ${{org}.audit.fail-closed:true}
        log.error("Audit insert failed (fail-open): {}", ex.getMessage(), ex);
    }
}
```

All writes flow through this one service: actor resolution (from the security context, in a try/catch), request metadata (IP, endpoint), persistence. Fail-closed is the default — an audit insert failure rolls back the business action. Fail-open is acceptable ONLY for local dev via configuration.

### 4. Repository — exactly 3 queries

By patient (the hot accounting-of-disclosures query: `patient_uuid` + date range + category set, ordered by `recorded_at DESC`), by actor, by event type. Resist adding more; the surface is capped by design.

### 5. Append-only table

The DDL above. The JPA entity is an immutable row: no auditable base entity, no `@LastModifiedDate`/`@CreatedBy` machinery on this table — those stamps imply updates, and this table never updates.

### 6. Admin endpoint — accounting of disclosures

```java
@GetMapping("/patient/{patientUuid}")
@PreAuthorize("hasAuthority('COMPLIANCE_OFFICER')")  // or the repo's admin authority — discover, do not invent
public AccountingOfDisclosuresResponse report(@PathVariable UUID patientUuid,
        @RequestParam LocalDate from, @RequestParam LocalDate to) { ... }
```

Dates convert to UTC instants with an exclusive end (`to.plusDays(1).atStartOfDay().toInstant(UTC)`). Cap the response row count and set a `truncated` flag when the cap hits.

### 7. Explicit auth hooks — NOT `@Audited`

```java
try {
    // ... existing auth logic ...
    auditLogService.logAuth(LOGIN_SUCCESS, SUCCESS, username, user.getIamId(), null);
    return response;
} catch (AuthException ex) {
    auditLogService.logAuth(LOGIN_FAILURE, FAILURE, username, null, ex.getMessage());
    throw ex;
}
```

Auth events call the service directly because failed logins must record the ATTEMPTED username when actor resolution fails, and auth paths often bypass normal SecurityContext population.

## Anti-Pattern Review Checklist

Flag these on sight in any review. Items 2 and 6 report as VIOLATION under the compliance taxonomy; judge the rest by exposure.

1. Using app logs (`log.info`) as the audit trail — not tamper-evident, not queryable, subject to rotation.
2. Missing read logging — required by 164.312(b) (audit controls), and read records feed the 164.528 accounting response; report as VIOLATION.
3. Timestamps without timezone — cross-system correlation becomes impossible; always UTC with offset.
4. Controller-layer-only capture — background jobs, queue consumers, and batch processors bypass it.
5. Audit writes sharing the business transaction (no `REQUIRES_NEW`) — FAILURE events are rolled back with the business tx, and an audit error poisons the business transaction instead of being handled by the fail-closed/fail-open policy.
6. Spring Data `@CreatedBy`/`@LastModifiedBy` mistaken for audit logging — last-modifier metadata is not a history, not a read log, not tamper-evident; if it is all that exists, report as VIOLATION.
7. Audit table with UPDATE/DELETE granted to the app user — violates 164.312(c)(1); one-line fix.
8. Logging PHI in free-text message or note fields — creates a second PHI surface; structured fields and IDs only.
9. Logging passwords, tokens, or full request bodies into `payload` — a secondary secret store.
10. Mixing audit events with application logs in the same pipeline — different retention, access, and sensitivity; the table is the source of truth.
11. No admin query endpoint — "who accessed my chart?" becomes hand-crafted SQL; a 164.528 response gap.
12. DELETE-by-age retention jobs — one job run wipes HIPAA evidence before the retention window expires.
13. Break-glass built but never reviewed — if it exists, compliance must review sessions on a schedule; do not build it otherwise.

## Behavioral Verification Checklist

Assert all eight before calling audit work done:

1. A successful login writes a `LOGIN_SUCCESS` row.
2. A failed login writes a `LOGIN_FAILURE` row with the reason and the attempted username.
3. A PHI read writes a row with `patient_uuid` populated.
4. A PHI create/update writes a row with `action` = C or U.
5. A bulk export writes an EXPORT-category row with `payload.filterScope` and `payload.rowCount`.
6. The admin endpoint returns every event for a test patient over a date range.
7. `UPDATE audit_log` as the app DB user fails with permission denied.
8. When the audit insert fails: fail-closed rolls back the business action; fail-open logs a loud error.

## Scope Guardrail — the Floor Is the Deliverable

The pattern above is the default deliverable and is HIPAA-compliant as-is. The upgrades below are added ONLY when compliance, legal, or written org policy demands them — and each is gated on a human process existing, not on engineering appetite. Push back on gold-plating.

| Upgrade | Add only when |
|---|---|
| Hash chain + integrity verifier | Compliance or HITRUST requires cryptographic proof AND someone owns responding to mismatch alerts |
| Outbox relay | The audit DB is separately hosted or unreliable AND ops owns monitoring the relay backlog |
| Object-lock (WORM) archive | Written policy requires it (e.g. 21 CFR Part 11) AND a restore/query process is documented |
| Break-glass flow | A written break-glass policy exists AND compliance reviews sessions on a schedule |
| Anomaly detection | A privacy officer or SOC will actually review the alerts |
| SIEM fanout | The org runs a SIEM AND the audit feed has a named owner |

## Migration Note

The `REVOKE`/`GRANT` statements ship as a migration changeset (Liquibase, Flyway — whichever the repo uses) guarded by a role-existence precondition, so local dev environments without the production role do not break. Write the role-existence check for the discovered engine — `pg_roles` shown for PostgreSQL. Liquibase shape:

```yaml
preConditions:
  - onFail: MARK_RAN
  - sqlCheck:
      expectedResult: "1"
      sql: "SELECT COUNT(*) FROM pg_roles WHERE rolname = '{app_user}'"
```

Verify the grants actually work against the repo's real app DB user before the work is declared done (verification item 7).

## Key Conventions Summary

| # | Rule |
|---|---|
| 1 | Annotate service methods, never controllers — background jobs must be covered |
| 2 | Every PHI read emits an event — missing READ logging is the #1 HIPAA gap |
| 3 | Everything leaving the org is an EXPORT event, including capability transfer (presigned URLs) |
| 4 | `recorded_at` is set at event time in UTC by the app — never the local clock, never a DB default |
| 5 | `AuditLogService` is the single write seam; every audit write uses `REQUIRES_NEW` |
| 6 | FAILURE events emit and the original business exception rethrows — never masked by an audit exception |
| 7 | `audit_log` rows are immutable — `REVOKE UPDATE, DELETE` from the app user; no entity-audit stamping |
| 8 | `actor_iam_id` may be NULL (failed logins, SYSTEM); failed logins still record the attempted username |
| 9 | `patient_uuid` is the accounting-of-disclosures key — populate it on every patient-linked event |
| 10 | Payload holds sanitized scalars only, strings truncated to 200 chars — never secrets, bodies, or clinical free-text |
| 11 | Bulk exports always populate `payload.filterScope` and `payload.rowCount` |
| 12 | The repository stays at exactly 3 queries: by patient, by actor, by event type |
| 13 | Admin endpoint: compliance/admin authority, UTC exclusive-end dates, row cap with truncated flag |
| 14 | Grants ship as a migration with a role-existence precondition; fail-closed default, fail-open local dev only |
| 15 | Ship the floor; upgrades require a compliance demand AND an existing human process |
