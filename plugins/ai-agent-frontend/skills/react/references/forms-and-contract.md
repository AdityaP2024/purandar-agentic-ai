# Contract Fidelity, Forms, and API Layer

Read when: consuming the tech-spec's Section 5, building any form, or wiring a service/hook to an endpoint.

## Section 5 Is Verbatim

Section 5 of `docs/tickets/<KEY>/tech-spec.md` is drop-in. Use its endpoint signatures, shapes, names, error mappings, and field bindings exactly as written. **Any gap or ambiguity is a stop-and-surface to the developer — NEVER a guess.** An invented name that happens to look plausible is the worst defect this agent can produce.

**5(e) Frontend consumption.** Create the service functions and hooks with exactly the names and paths the spec lists, following the project's existing service-layer layout and cache-key scheme.

```typescript
// VIOLATION: hardcoded string key bypasses the project's existing key factory
useQuery({ queryKey: ['members', 'list'], queryFn: fetchMembers });

// CORRECT: keys come from the factory; invalidations follow Section 5(e) exactly
useQuery({ queryKey: memberKeys.list(filters), queryFn: fetchMembers });
```

**5(d) Error mapping.** Implement each row's Frontend Handling label exactly: INLINE-FORM-ERROR sets the named field's error through the form library; TOAST surfaces a non-field failure; REDIRECT navigates to the destination the row names; RETRY applies the stated policy, then the stated fallback.

```typescript
// VIOLATION: every failure collapses into one generic toast, flattening the 5(d) table
onError: () => toast.error('Something went wrong');

// CORRECT: handling branches per the 5(d) row for each error condition
onError: (err) => {
  if (err.status === 400) setFieldError(err.field, err.message); // INLINE-FORM-ERROR
  else if (err.status === 401) navigate(sessionExpiredPath);     // REDIRECT per 5(d)
  else toast.error(messages.saveFailed);                         // TOAST per 5(d)
};
```

**5(f) Field bindings.** Each form field maps to its API request path with the exact transform named in the row ("date -> ISO-8601 string", "trim whitespace", "none"). No extra fields, no renamed paths, no invented transforms.

**5(b) Validation.** Client-side validation mirrors the 5(b) rules — required, max length, format, allowed values — so the form rejects exactly what the backend rejects. Client validation is a usability layer; **the server remains authoritative.**

## The Transport Seam

- **One configured client.** Every API call routes through it. Instantiating a second HTTP client, or calling `fetch` directly from a component or feature hook, bypasses auth headers, context headers, error mapping, and audit logging in one move — always a finding.
- **Components import feature hooks**, never the transport or generated request functions directly.
- **Generated API code is never hand-edited.** Regeneration overwrites it; a spec defect is repaired in the generator's transform step, and a shape mismatch is fixed in the feature's types, never cast around.
- **Where the backend wraps responses in an envelope, unwrap it once, in the seam.** Doing it per hook means every hook changes the day the envelope does. An API that returns bare payloads needs no unwrapping — do not add a layer for one that does not exist.
- Where a backend message is rendered to users, confirm it is user-facing and free of sensitive data before displaying it verbatim — a leaked server exception string is a compliance problem in the UI, not just an ugly one.

## One Schema, Two Jobs

Where the project uses a schema validation library, the same schema **validates the form and types the request payload**, so the two cannot drift.

**Every rule carries its own finished, user-facing message.** A bare format rule renders the library's default gibberish to a real user — that is a finding.

## Forms

- **Every field goes through the project's field wrapper, where the project has one** — so label, required marker, error text, and the error's programmatic association are wired once. A raw input dropped into a form beside an existing wrapper re-implements all four, usually incompletely. **Where the project has no wrapper**, wire those four directly on each field and keep them consistent; whether to introduce a wrapper is a plan-gate observation for the developer, not something to build inside a feature ticket.
- **The error message is the finished sentence**, rendered verbatim. Nothing resolves or transforms it at render time.
- **The error must be programmatically associated with the input the user is focused on.** Wrapper libraries frequently do not forward a describedby attribute to the inner native element — verify it lands on the actual `input`, not only on the outer container. **This is the single most common silent accessibility failure in form code.**
- **Conditional fields use a scoped watch**, not a whole-form subscription, so typing in one field does not re-render every other.
- **Submit is disabled while submitting**, and the in-flight state is visible. Two clicks must not create two records.
- **A dirty form warns before navigating away.**
- **Field arrays key on a stable id**, never the array index.
- **Server-side field errors map back onto their fields** (the 422-style path), not into a generic toast that leaves the user hunting.

## File Upload

Where a screen accepts files:

- Validate **type and size before upload**, with the limit stated in the message rather than a bare rejection.
- Show **per-file progress** and allow removing a file before submit.
- Handle **partial failure** in a multi-file upload — which succeeded, which did not, and what happens next.
- A large upload needs a **longer timeout than the default request timeout**, set per request rather than raising it globally.
- Never trust the client-side type check as security; it is a usability guard.
