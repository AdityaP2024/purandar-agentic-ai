# Testing

Read when: writing any test, or deciding whether a screen is done.

## Principles

- **Behavior over implementation.** Assert what the user sees and does — rendered text, roles, interactions — not internal state, hook call counts, or child-prop wiring. A test that breaks on a refactor with unchanged behavior is a finding.

```tsx
// VIOLATION: asserts internal wiring — breaks on any refactor, proves nothing about behavior
expect(useMembersQuery).toHaveBeenCalledTimes(1);
expect(wrapper.find(MemberTable).prop('members')).toHaveLength(3);

// CORRECT: asserts what the user experiences
expect(await screen.findByRole('row', { name: /MEMBER-PLACEHOLDER-1/ })).toBeVisible();
```

- **Query by role and accessible name** wherever possible. It asserts behavior and accessibility in one line: a control with no accessible name cannot be found this way, which is the point.
- **Every AC maps to at least one test**, and the implementation report's AC coverage checklist (shared-standards exact format) cites them.
- **Where the project has a contract-test convention, contract tests lock a shared primitive's prop API and its variants**, so a change cannot silently break consumers. Without that convention an ordinary behavior test covering the same variants is sufficient — follow the project's existing test kinds rather than introducing a new tier. Where an ordering or side-effect rule cannot be expressed in the type system — a masked field outranking a custom renderer, a query-tab change replacing rather than pushing — a contract test is the only thing holding it. Those rules regress silently and look correct in review.
- **Error-mapping states are asserted.** For each Section 5(d) row exercised: the 400 path shows the inline field error, the 401 path redirects, the 5xx path retries then toasts — each per its row, not a single generic failure test.
- **No sensitive data in fixtures.** Placeholder IDs and obviously-fake values only, in fixtures, factories, and assertions (`hipaa` skill rule; restated because test data is the most common leak).
- **Test files are type-checked.** Excluding them from the type program lets a test referencing a renamed prop or a deleted export pass silently, while the editor disagrees with the gate.
- **Mock at the boundary the project already uses** — stub the request function or seed the cache. Do not introduce a new mocking layer alongside an existing convention.
- **Run the project's own test script** and report failures honestly with output. Never claim done over a failing test; **never weaken a test or assertion to make it pass.**

## Scenario Coverage — Line Coverage Is Not Enough

Walk the row matching what you built and cover every applicable scenario. **A screen with no empty-state test or no error-state test is not done, regardless of line coverage.**

### Any list or table screen

loading · empty · error with retry · exact row count · pagination next/prev · pagination resets on filter change · sort ascending/descending/none · filter apply, clear, and combine · debounced search fires once, not per keystroke · **URL restore on refresh** · **back-navigation restore** · row select by mouse and keyboard · permission-hidden columns and actions · masked sensitive cells · overflow truncation without layout break · infinite scroll has no duplicate ids and stops at the end · no accessibility violations.

### Any form

valid submit with typed payload · every validation rule renders its message · error programmatically linked to its input · submit blocked while invalid · double-submit prevented · server field errors map onto their fields · dirty-navigation guard · reset returns to defaults · disabled while submitting · masked field reveal behavior.

### Any detail screen

loading and error · not-found distinct from forbidden · sub-tab reflected in the URL · refresh restores the active tab.

### Any hook

defaults with no input · parameter coercion including invalid values · tampered input falls back without throwing · guarded queries do not fire on a null id · stable references across equal inputs · **a superseded request does not overwrite a newer result**.

### Any utility

happy path · every branch · boundaries (min, max, zero, empty, first, last) · null and wrong-type input fall back safely · timezone edges (DST, UTC offset, midnight).

### Cross-cutting, every feature

offline · timeout · malformed or partial API data does not crash render · duplicate concurrent requests dedupe to one · session end or context switch clears cache and persisted state · **out-of-order responses render the latest request's data**.

## Environment Stubs Are Deliberate No-Ops

A headless test environment implements no layout, so observers report zero and media queries match nothing. Stub them globally, and understand what each stub means for assertions:

| Global | Constructed by | Why a no-op is correct |
|---|---|---|
| media-query matcher | any viewport hook | default: nothing matches. A test asserting a viewport overrides it itself. |
| resize observer | width-measuring primitives | every element reports zero width, so measurement-dependent behavior takes its unmeasured fallback |
| intersection observer | infinite-scroll triggers | nothing is ever "in view" without layout, so the callback would never fire regardless |

Geometry-dependent behavior (pinned columns, intersection triggers) **cannot be asserted** in that environment at all — assert the fallback the component takes when measurement is unavailable. Without the stubs, components throw on mount rather than failing an assertion, which is why they belong in global setup rather than individual files.

## Coverage Gates

Where the project declares thresholds, they are part of done. A sensible shape: a global line/branch floor, with shared primitives and pure utilities held to a higher bar than feature screens — those are the code every screen depends on and the code where a branch is cheapest to test.
