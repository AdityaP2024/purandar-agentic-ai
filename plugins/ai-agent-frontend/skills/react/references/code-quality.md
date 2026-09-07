# Component Quality, TypeScript, and Data Structures

Read when: structuring a component, typing anything, or writing logic that loops, looks up, sorts, or traverses.

## Component Quality

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

**When a component outgrows one responsibility, decompose it — never raise the limit.** Three destinations always exist:

| Overflow | Goes to |
|---|---|
| Sub-components, render blocks | a `parts/`-style folder beside the component |
| Stateful logic | a hook |
| Columns, filters, tabs, schema | config |

If the project's lint rules cap function size, that cap is the contract; **adding an exemption entry is a finding** — a list of disabled rules is how a lint rule quietly stops enforcing anything.

**Logic reuse via hooks.** Shared behavior (fetch-and-transform, debouncing, permission checks) extracts into a custom hook, not copy-paste. DRY follows the **rule of three**: tolerate a second occurrence; a third copy is a finding and the extraction point.

**Memoize appropriately, not blindly** — see the performance reference for the full rule and its prerequisites.

**No prop-drilling past two levels** when the project has a sanctioned alternative (existing context, the store, or component composition). Threading a prop through two intermediaries that never read it is a finding — but prefer composition (`children`) over adding a new context provider the project does not already have.

**Subscribe narrowly.** A hook that subscribes a component to an entire store, or opens its own media-query/observer subscription per consumer, multiplies listeners and re-renders. Shared computations (viewport tier, permission set) are computed once at a provider and read from context. A gated element repeated across a large list subscribes to *its one key*, never the whole permission object.

**Effects are for synchronizing with something outside React.** Deriving state in an effect and setting it is a finding — derive during render. An effect with no cleanup that subscribes, times, or observes is a leak.

## TypeScript

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
- **Make the impossible state unrepresentable at the prop level too.** Where two props are mutually exclusive, the type says so rather than a runtime warning. Where a required companion value exists (a pinned column that must declare a width), the type requires it — a runtime desync costs more than a compile error.
- **Derive the placeholder from the data, not a second flag.** A component taking `data: T | undefined` cannot express the impossible `loading={false}` with no data.
- **Respect strict-index settings.** Under `noUncheckedIndexedAccess`, a map lookup or array index is `T | undefined` — narrow it. A non-null assertion (`!`) to silence it is a finding.
- **A type assertion (`as`) is a claim you are responsible for.** Prefer narrowing; where an assertion is genuinely required, it sits at one boundary, not scattered through a feature.

## Data Structures and Algorithms

Pick the structure whose cost for the **hot operation** is constant, and expose it as a typed helper rather than scattering loops across features.

| What you actually do | Right structure | Avoid |
|---|---|---|
| Look up an entity by id | `Map` / keyed record | `arr.find(x => x.id === id)` in a render or loop — O(n²) |
| "Is this selected / present?" | `Set` | `arr.includes(id)` in a hot path |
| Group rows by a key | `Map<K, T[]>` | nested loops with manual bucket init |
| Ordered unique list | `Set` spread to array | `filter` + `indexOf` — O(n²) |
| Count / frequency | `Map<K, number>` | object accumulation with prototype-key pitfalls |
| Fixed enum → label/color/icon | keyed record registry | `switch` / `if-else` chains |
| Hierarchy (nav tree, threads) | tree + one shared traversal helper | ad-hoc recursion re-written per feature |
| Bounded cache (recently viewed) | LRU over insertion-ordered map | an object that grows forever |
| Many-to-many (role → permissions) | `Map<K, Set<V>>` | array of pairs plus filter |

For complex logic, reach for the **named algorithm** rather than nested conditionals:

| Complex logic | Algorithm |
|---|---|
| Find in a sorted list | binary search — O(log n), not a scan |
| Order by several keys | a composed comparator, not chained if/else |
| Merge two sorted streams | two-pointer merge, not concat-and-resort |
| Detect overlapping intervals | sweep over sorted intervals — O(n log n), not pairwise |
| Walk a graph or dependency chain | BFS/DFS **with a visited set** — never recurse without a cycle guard |
| Rapid UI events | debounce or throttle before optimizing the body |
| Expensive repeated derivation | memoize by key, bounded |
| Retry a flaky request | exponential backoff, not a fixed interval |

**Rules:**
- A helper used by two or more features lives in the project's shared utility location, typed and tested once — never copy-pasted.
- `Map`, `Set`, and normalized state are **mutable**; always write a fresh container on update.
- Hold entity collections **normalized** (lookup map plus an order array) only when you genuinely need id-addressing; otherwise let the cache layer own the list. Do not duplicate server data into a store just to normalize it — derive at the edge.
- **Don't over-engineer:** for ten items a plain `find` is correct. Reach for these when N is large or the path is hot, and measure against the project's budgets.
