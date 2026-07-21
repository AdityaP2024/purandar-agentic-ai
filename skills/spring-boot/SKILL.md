---
name: spring-boot
description: read when implementing or reviewing Java/Spring Boot code — layering, SOLID/KISS/YAGNI/DRY as checkable review rules, tech-spec contract fidelity, migrations, and testing standards for the backend-springboot agent
---

# Java / Spring Boot Engineering Standards

Standards card for the `backend-springboot` agent. Read `shared-standards` first (persona, hard rules, gates, decision log protocol, report contracts) and the `hipaa` skill for anything touching patient or member data — this card references both and never restates them. Findings against this card use the technical review taxonomy and report format defined in `shared-standards` (BREAKING > WARNING > SUGGESTION, one-line count summary).

## Discovery Preamble — run before writing or judging any code

Nothing on this card names a version, directory, or org constant. Every stack fact comes from the consuming repo at task time:

| Fact | Discover from |
|---|---|
| Java version, Spring Boot version, modules | `pom.xml` / `build.gradle` |
| Migration tool | build-file plugins/dependencies plus the migrations directory layout |
| Package layout and layer naming | existing packages — whatever the repo actually uses, not an assumed `controller/service/repository` split |
| Error envelope and exception handler | existing `@RestControllerAdvice` / `@ControllerAdvice` classes and their response shape |
| Test frameworks and DB test strategy | test dependencies plus existing tests (Testcontainers-style, embedded DB, slices) |
| DTO/entity mapping approach | existing mapping code (manual, generated, or library-based) |
| Correlation ID and logging conventions | logging config, filters, and existing log statements |

Where the tech-spec speaks (Sections 5, 6, 10), the spec wins over repo habit for the contract itself. Where the spec is silent on a convention, the repo's existing code IS the convention. A gap or ambiguity in Section 5 is a stop-and-surface to the developer, never a guess.

## Design Principles as Review Rules

Checkable rules, not philosophy. Each names the finding a reviewer records and the fix an implementer applies.

### SRP — one reason to change per class

A class serving two masters is a finding: a controller doing business logic, or a service doing HTTP concerns (status codes, headers, `ResponseEntity`).

```java
// VIOLATION: controller owns a business rule and the persistence flow
@PostMapping("/referrals")
public ResponseEntity<ReferralResponse> create(@RequestBody ReferralRequest req) {
    if (referralRepository.countByMemberId(req.memberId()) >= limit) {
        throw new LimitExceededException();
    }
    Referral saved = referralRepository.save(toEntity(req));
    return ResponseEntity.status(201).body(toResponse(saved));
}

// CORRECT: controller maps HTTP; the service owns the rule and the transaction
@PostMapping("/referrals")
public ResponseEntity<ReferralResponse> create(@Valid @RequestBody ReferralRequest req) {
    return ResponseEntity.status(HttpStatus.CREATED).body(referralService.create(req));
}
```

### OCP + DIP — extend through the project's existing abstractions

Depend on the abstractions the project already has. A new `switch`/`if-else` chain on a type code where the repo already has a polymorphic seam (strategy interface, handler registry, subclass hierarchy) is a finding — add an implementation to the seam instead.

```java
// VIOLATION: new switch-on-type beside an existing NotificationSender seam
switch (channel) {
    case EMAIL -> sendEmail(message);
    case SMS -> sendSms(message);
}

// CORRECT: add an SmsNotificationSender implementing the existing NotificationSender
// interface; the dispatch the project already has picks it up
```

Do not invert this into speculation: if no seam exists and the spec needs exactly one behavior, a plain method is correct (see YAGNI).

### LSP and ISP — concrete smells, one line each

- LSP: an implementation that throws `UnsupportedOperationException` (or silently no-ops) on an inherited method does not fit its seam — split the abstraction or do not implement it.
- ISP: a class forced to implement interface methods it leaves empty means the interface is too fat for that client — depend on the narrow piece actually used.

### KISS — the simplest design that satisfies the spec

Cleverness that needs a comment to justify itself is a finding. If the plain version does exactly what spec Sections 5, 6, and 9 require, the plain version is correct.

```java
// VIOLATION: needs a comment to defend itself
// fold status transitions through reduce so we avoid an explicit loop
var state = events.stream().reduce(initial, (s, e) -> TRANSITIONS.get(s).apply(e), (a, b) -> b);

// CORRECT: the obvious loop; no defense needed
var state = initial;
for (var event : events) {
    state = transition(state, event);
}
```

### YAGNI — every element cites an AC or is deleted

No speculative parameters, config flags, interfaces-with-one-implementation, generic "engines", or "for future use" code. The test is citable need: name the ticket AC (or tech-spec section) that requires it, or delete it.

```java
// VIOLATION: an interface and a flag no AC asks for
public interface ReferralCreator { ReferralResponse create(ReferralRequest req); } // single impl, no second in the spec
ReferralResponse create(ReferralRequest req, boolean skipValidation); // "for future batch use"

// CORRECT: exactly the method Section 5 needs
ReferralResponse create(ReferralRequest req);
```

### DRY — rule of three, real duplication only

Duplicating a small block twice is cheaper than the wrong abstraction; extract on the third occurrence. Never merge coincidental similarity — two blocks that look alike today but change for different reasons stay separate, because merging them couples unrelated future changes. Two findings here: a third-plus copy of the same knowledge, and an abstraction that merged things that merely looked alike (the fix for the second is to inline it back apart).

## Layering Rules

| Layer | Owns | Never contains |
|---|---|---|
| Controller | HTTP mapping, `@Valid` boundary validation, status codes, DTOs in/out | business rules, repository calls, `@Transactional` |
| Service | business logic, orchestration, transaction boundaries — `@Transactional` lives here and only here | HTTP types (`ResponseEntity`, servlet classes), status codes |
| Repository | persistence only: queries and projections | business rules, `@Transactional`, response shaping |

DTOs at every boundary. Entities are NEVER serialized into a response — this is simultaneously a layering rule and the `hipaa` skill's response-shaping rule (field-level filtering: only what the consuming screen renders).

```java
// VIOLATION: entity returned from a controller — serializes every column, PHI included
@GetMapping("/members/{id}")
public Member get(@PathVariable String id) {
    return memberRepository.findById(id).orElseThrow();
}

// CORRECT: DTO carries exactly the fields Section 5(c) names
@GetMapping("/members/{id}")
public MemberSummaryResponse get(@PathVariable String id) {
    return memberService.getSummary(id);
}
```

## Contract Fidelity — tech-spec Section 5 is verbatim

- **Request validation:** implement every Section 5(b) rule as Bean Validation at the boundary — `@Valid` on the controller parameter; `@NotBlank`, `@Size`, `@Pattern`, and friends matching the spec's stated rules exactly. Cross-field rules go where the repo already puts them (custom validator or service-layer check — discover).
- **Error mapping:** implement Section 5(d) exactly — status, condition, body shape per row — through the project's EXISTING centralized exception handler and error envelope. Discover the `@RestControllerAdvice` and envelope class first; NEVER invent a second handler or a parallel error shape. If `docs/decisions.md` carries an entry on the error convention, follow it and cite the ID. If the repo has no centralized handler at all, that is a stop-and-surface (and likely a new decision-log entry via the shared-standards protocol), not an ad-hoc `try/catch` in the controller. A Section 5(d) body shape that cannot be produced through the existing handler/envelope is a CONFLICT — stop with a conflict gate quoting the spec row and the envelope class verbatim; never fork a second shape, never silently reshape.
- **Names and bindings:** endpoint signatures, request/response shapes, operation names, and Section 5(f) field bindings are used exactly as written. Anything missing or ambiguous stops the work and goes to the developer.

## Data Changes — tech-spec Section 6

- Every schema change ships as a migration file using the migration tool discovered from the build. Never direct DDL, never auto-generated schema edits.
- NEVER edit an already-applied migration. Corrections are new migrations; migrations are additive.
- Every new index is justified by the query it serves, per the Section 6 index table. An index with no named query is a YAGNI finding.
- Migration file naming and sequencing follow the repo's existing migrations directory — read it before naming yours.

## Testing Standards — tech-spec Section 10

- **Services:** unit-test without a Spring context where possible — plain JUnit with mocks or fakes for collaborators. Booting `@SpringBootTest` for logic plain construction can cover is a finding (slow, obscures the unit).
- **Repositories and integration paths:** test against a real database in the style the repo already uses (Testcontainers-style if present — discover; otherwise the repo's existing slice or embedded approach). Migrations run as part of these tests.
- **Coverage gate:** discover whether the project enforces a coverage threshold. A gate is a configured rule that FAILS the project's own build/check/verify command (or a CI quality-gate config the repo carries) when coverage falls below a stated threshold — e.g. a JaCoCo check goal with rules bound to verify, a jacocoTestCoverageVerification task wired into check, a quality-gate config with a failing threshold. A plugin that only MEASURES or REPORTS coverage (report/prepare-agent goals, a report-only CI step) imposes nothing and falls under the no-gate branch. A threshold-bearing config the repo defines but never wires into any command is surfaced in the report as found-but-dormant, neither run as a gate nor silently ignored. If a gate exists, the implementation MUST pass it, run via the project's own gate command. Two carve-outs, both resolved by honesty rather than by edits: (a) a gate failure caused by pre-existing untested code that tests for the in-scope change cannot lift is reported as exactly that — the gate result verbatim plus the attribution — never fixed by threshold/exclusion/rule edits and never by out-of-scope tests for code no AC touches (offer legacy testing to the developer as an option, do not do it unbidden); (b) a gate the environment cannot run is reported with the inability and its cause. Failing the gate for reason (a) or (b) and saying so is compliant; hiding either is the defect. NEVER lower a threshold, add an exclusion, or delete a quality-gate rule to make the gate pass — that is a BREAKING finding, the same class as weakening a test. If NO gate exists, do NOT impose one: coverage adequacy is behavioral (the negative-path, edge-case, audit-event, and test-quality rules below), and the report states qualitatively what is exercised.
- **Negative paths:** every Section 5(d) error row gets a test asserting its status code and body shape through the REAL exception handler, using the repo's existing MockMvc/WebTestClient convention. A controller test suite that exercises only the success path is a finding.
- **Edge cases:** every Section 9 row maps to at least one test, or the reason it does not is stated per row — in the spec's Section 10 where the spec already carries it, otherwise in the implementation report's test-results section (the implementer never edits the spec). An unmapped edge case with no stated reason in either place is a finding.
- **Audit events:** when the change emits audit events (spec Section 8), tests assert them per the audit-logging skill's Behavioral Verification Checklist where the repo's test style allows — at minimum: the success path writes the expected event, the failure path writes a FAILURE-outcome event, and the audit write never masks the business exception. The three minimum assertions are the default and are presumed possible; any of them — or any further Behavioral Verification Checklist item — skipped under "where the repo's test style allows" is listed in the implementation report naming the specific repo constraint that blocks it (e.g. audit writes leave the process through an aspect with no observable test seam). A skipped item with no named constraint is a finding; the clause is never grounds for checking the audit box.
- **Coverage mapping:** every AC in the spec maps to at least one test; the implementation report carries the AC coverage checklist in the exact `shared-standards` format.
- **Test quality** — each rule is a checkable finding:
  - Assert behavior, not implementation — verifying a mock was called where a state or outcome assertion is possible is a finding.
  - Over-mocking is a finding: never mock value objects or the class under test.
  - Tests are order-independent; a test that passes only after another has run is a finding.
  - Every ORDERED constraint from Section 5(b) (min/max length, numeric min/max, ranges) is tested at the limit (passes) and one past it (fails); every MEMBERSHIP or FORMAT constraint (allowed values, pattern/format, required/non-blank) is tested with one valid value accepted and one representative invalid value rejected.
  - Fixtures come from the repo's existing builder/factory conventions — a parallel fixture style beside an existing one is a finding.
- **Fixtures:** NO PHI in any fixture, factory, or assertion — placeholder IDs and obviously fake values only (`member-0001`, `TEST_LASTNAME`), per the `hipaa` skill.
- **Honesty:** a failing test is reported as a failure, with its output. NEVER weaken an assertion, broaden a matcher, or delete a test to make the suite pass — that is a defect in the report, not a fix.

## Observability Hygiene

- Structured logs with surrogate IDs only — the never-log list and the Java contrastive pairs live in the `hipaa` skill; apply them at every log call and exception message.
- Attach or propagate the correlation ID if the project has one (discover from logging config and filters); error responses carry it per the project envelope.
- No `System.out`, `System.err`, or `printStackTrace()` — the project logger only.

```java
// VIOLATION: stdout bypasses the logging pipeline and its safeguards
System.out.println("created referral " + referral);

// CORRECT: project logger, surrogate ID only
log.info("Referral created id={}", referral.getId()); // HIPAA: log surrogate ID only
```

## Key Conventions Summary

| # | Rule |
|---|---|
| 1 | Discover stack facts from build files and existing code — never assume versions, layout, or tools. |
| 2 | Tech-spec Section 5 is verbatim; a gap or ambiguity is a stop-and-surface, never a guess. |
| 3 | Controller = HTTP only; service = logic plus `@Transactional`; repository = persistence only. |
| 4 | DTOs at every boundary; entities never serialized to responses (hipaa response shaping). |
| 5 | Section 5(b) rules become Bean Validation at the boundary; cross-field rules go where the repo puts them. |
| 6 | Section 5(d) errors flow through the existing exception handler and envelope — never a second one. |
| 7 | One reason to change per class; extend existing polymorphic seams instead of new switch-on-type. |
| 8 | Simplest design that satisfies the spec; cleverness needing a justifying comment is a finding. |
| 9 | Every parameter, flag, and interface cites an AC or is deleted. |
| 10 | Extract duplication on the third occurrence; never merge coincidental similarity. |
| 11 | Schema changes only via the discovered migration tool; never edit an applied migration; every index serves a named Section 6 query. |
| 12 | Unit-test services without a Spring context; integration-test repositories against a real database. |
| 13 | Every AC and Section 9 edge case maps to a test; every Section 5(d) row asserted through the real exception handler. |
| 14 | Pass the project's coverage gate when one is configured — never lower a threshold, add an exclusion, or delete a quality-gate rule; no gate configured means none is imposed; a shortfall in-scope tests cannot lift is reported, not engineered around. |
| 15 | No PHI in fixtures or logs; no `System.out`; never weaken a test to make it pass. |
