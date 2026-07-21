---
name: react
description: read this when implementing or reviewing React/TypeScript frontend code — covers stack discovery, state ownership, tech-spec Section 5 contract fidelity, component quality, typing, accessibility, and testing rules
---

# React / TypeScript Engineering Standards

Standards card for the frontend-react agent. `shared-standards` applies first; this card adds the React/TypeScript specifics. Client-side PHI rules (console, browser storage, URLs, route params, analytics, error reporting) live in the `hipaa` skill — load it for any PHI-touching screen; nothing here restates those rules.

## Discover the Stack First — Never Assume

This card pins NOTHING: no library versions, no directory layout, no named state library. Before writing any code, discover the project's actual stack from `package.json` and the existing source:

| Fact | Where to Discover |
|---|---|
| Data-fetching / cache library | `package.json` dependencies plus existing service and hook files |
| Global state store | `package.json` plus existing store/provider setup |
| Form library | `package.json` plus existing form components |
| Router | `package.json` plus existing route definitions |
| Styling system | existing components (CSS modules, styled components, utility classes, UI kit) |
| Test runner and component-test library | `package.json` scripts plus existing test files |

Follow the project's existing conventions exactly — file layout, naming, cache-key factories, error boundaries, form patterns. Introducing a parallel convention alongside an existing one is a finding, even when the new one is arguably better. Where the tech-spec is silent, the consuming repo's existing code IS the convention.

## State Ownership

Rule of thumb: state lives in the narrowest scope all its readers share — promote it only when a real second reader appears, never speculatively.

| State Kind | Owner |
|---|---|
| Server data (fetched entities, lists, lookups) | the project's data-fetching/cache layer — never copied into a global store |
| Client state shared across unrelated components and NOT server data (session context, feature flags, cross-screen selections) | the project's global store |
| Form values and field errors | the form library's local state |
| Ephemeral UI state (open/closed, hover, active tab, unsubmitted input) | component state |

What does NOT go in the global store:

- Server data — the cache layer already owns identity, staleness, and refetch; a store copy is a second source of truth that drifts.
- Form values — the form library owns them; mirroring into a store doubles every keystroke for nothing.
- Ephemeral UI state — a modal flag in a global store couples unrelated components to one toggle.
- Anything derivable from existing state — derive at render time instead of storing the result.

```typescript
// VIOLATION: server data copied into the global store — two sources of truth
const { data } = useMembersQuery();
useEffect(() => { if (data) dispatch(setMembers(data)); }, [data]);

// CORRECT: readers consume the cache layer directly; the store never sees server data
const { data: members } = useMembersQuery();
```

## Contract Fidelity — tech-spec Section 5 Is Verbatim

Section 5 of `docs/tickets/<KEY>/tech-spec.md` is drop-in. Use its endpoint signatures, shapes, names, error mappings, and field bindings exactly as written. Any gap or ambiguity is a stop-and-surface to the developer — NEVER a guess.

**5(e) Frontend consumption.** Create the service functions and hooks with exactly the names and paths the spec lists, following the project's existing service-layer layout and cache-key scheme. Hardcoding a string cache key when the project has a key factory is a finding.

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

**5(b) Validation.** Client-side validation mirrors the 5(b) rules — required, max length, format, allowed values — so the form rejects exactly what the backend rejects. Client validation is a usability layer; the server remains authoritative.

## Component Quality — Review Rules

**Small and single-purpose.** A component that fetches data, transforms it, renders it, and handles three unrelated concerns is a finding — split data access into a hook and presentation into focused components.

```tsx
// VIOLATION: one component fetches, transforms, renders a table, and owns an edit dialog
function MemberPanel() {
  const [members, setMembers] = useState<Member[]>([]);
  useEffect(() => { api.fetchMembers().then((r) => setMembers(sortAndGroup(r))); }, []);
  // ...200 more lines of filter state, table markup, and dialog logic
}

// CORRECT: data access in a hook, presentation in a focused component
function MemberPanel() {
  const { data, isLoading } = useMembersQuery();
  return <MemberTable members={data ?? []} loading={isLoading} />;
}
```

**Logic reuse via hooks.** Shared behavior (fetch-and-transform, debouncing, permission checks) extracts into a custom hook, not copy-paste. DRY follows the rule of three, same as backend: tolerate a second occurrence; a third copy is a finding and the extraction point.

**Memoize appropriately, not blindly.** `React.memo` / `useMemo` / `useCallback` only for a measured problem or a concrete need (expensive transform over a large list, referential stability a dependency array relies on). Blanket memoization of every component and callback is a finding — it adds indirection and hides real dependency bugs.

**No prop-drilling past two levels** when the project has a sanctioned alternative (existing context, the store, or component composition). Threading a prop through two intermediaries that never read it is a finding — but prefer composition (`children`) over adding a new context provider the project does not already have.

## TypeScript Rules

- **No `any` on domain data.** Request and response types mirror the spec's Section 5(b)/(c) shapes field-for-field. At genuine unknown boundaries use `unknown` plus narrowing, never `any`.
- **Discriminated unions for state machines.** A view that is loading, loaded, or failed is one union with a discriminant — not independent booleans that can contradict each other.

```typescript
// VIOLATION: boolean soup — isLoading && isError is a representable, meaningless state
const [isLoading, setIsLoading] = useState(false);
const [isError, setIsError] = useState(false);

// CORRECT: impossible states are unrepresentable
type LoadState =
  | { status: 'loading' }
  | { status: 'loaded'; data: Member[] }
  | { status: 'error'; errorCode: string };
```

- **API types live in one place**, per the project's convention (shared types module, generated client types, per-feature type files — discover which). Redeclaring a payload shape inline at a call site is a finding.

## Responsiveness, Accessibility, and Definition of Done

- **The layout test:** before calling any layout done, ask "will this break at any width the project supports?" Discover the supported range from the project's existing breakpoints (theme config, CSS custom properties, utility classes) — never invent new breakpoint values.
- **Semantic elements:** `button` for actions, the router's link for navigation, native form elements over click-handling `div`s. Every input has an associated label. Every interactive element is keyboard-reachable and keyboard-operable.

```tsx
// VIOLATION: click-only div — invisible to keyboard and assistive technology
<div className="btn" onClick={onSave}>Save</div>

// CORRECT: a real button is focusable, keyboard-operable, and announced correctly
<button type="button" onClick={onSave}>Save</button>
```
- **Loading, empty, and error states are part of done.** Every data-driven view renders all three deliberately, tied to the tech-spec Section 9 edge cases (empty result set, permission denied mid-flow, partial failure across Section 7 seams). A screen that only handles the happy path fails review.

## Testing — per tech-spec Section 10

- **Behavior over implementation.** Assert what the user sees and does — rendered text, roles, interactions — not internal state, hook call counts, or child-prop wiring. A test that breaks on a refactor with unchanged behavior is a finding.

```tsx
// VIOLATION: asserts internal wiring — breaks on any refactor, proves nothing about behavior
expect(useMembersQuery).toHaveBeenCalledTimes(1);
expect(wrapper.find(MemberTable).prop('members')).toHaveLength(3);

// CORRECT: asserts what the user experiences
expect(await screen.findByRole('row', { name: /MEMBER-PLACEHOLDER-1/ })).toBeVisible();
```
- **Every AC maps to at least one test**, and the implementation report's AC coverage checklist (shared-standards exact format) cites them.
- **Error-mapping states are asserted.** For each Section 5(d) row exercised: the 400 path shows the inline field error, the 401 path redirects, the 5xx path retries then toasts — each per its row, not a single generic failure test.
- **No PHI in fixtures.** Placeholder IDs and obviously-fake values only, in fixtures, factories, and assertions (hipaa skill rule; restated because test data is the most common leak).
- **Run the project's own test script** (discover it from `package.json` scripts) and report failures honestly with output. Never claim done over a failing test; never weaken a test or assertion to make it pass.

## Key Conventions Summary

| Topic | Rule |
|---|---|
| Stack facts | Discovered from package.json and existing code at task time — never assumed, never pinned |
| Existing conventions | Follow the project's pattern; introducing a parallel convention is a finding |
| Server data | Lives in the data-fetching/cache layer, never copied into the global store |
| Global store | Cross-cutting client state only; no server data, form values, or ephemeral UI state |
| Form values | Owned by the form library's local state |
| Ephemeral UI state | Component state, narrowest scope that serves all readers |
| Section 5 fidelity | Names, shapes, keys, mappings, transforms verbatim; any gap is stop-and-surface |
| Cache keys | Through the project's existing key factory, never hardcoded strings |
| Error handling | Implement each 5(d) row's INLINE-FORM-ERROR / TOAST / REDIRECT / RETRY exactly |
| Validation | Mirror 5(b) rules client-side; the server stays authoritative |
| Component scope | Single-purpose; fetch + transform + render + multiple concerns in one component is a finding |
| Memoization | Only for measured problems; blanket memo/useMemo/useCallback is a finding |
| Prop drilling | Not past two levels when a sanctioned alternative exists |
| TypeScript | No any on domain data; discriminated unions for state machines; API types in one place |
| Done means | Loading/empty/error states rendered, layout holds across supported widths, behavior-level tests per AC, no PHI anywhere |
