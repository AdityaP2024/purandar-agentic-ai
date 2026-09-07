# State Ownership and Persistence

Read when: deciding where a piece of state lives, wiring filters/search/pagination, or making a screen survive refresh and Back.

## State Ownership

State lives in the **narrowest scope all its readers share** — promote it only when a real second reader appears, never speculatively.

| State Kind | Owner |
|---|---|
| Server data (fetched entities, lists, lookups) | the project's data-fetching/cache layer — never copied into a global store |
| Client state shared across unrelated components and NOT server data (session context, feature flags, cross-screen selections) | the project's global store |
| Form values and field errors | the form library's local state |
| Ephemeral UI state (open/closed, hover, active tab, unsubmitted input) | component state |
| Filters, search, sort, pagination, active tab | the URL |
| Local ergonomics (panel open, density, expanded rows) | scoped browser storage |

What does NOT go in the global store:

- **Server data** — the cache layer already owns identity, staleness, and refetch; a store copy is a second source of truth that drifts.
- **Form values** — the form library owns them; mirroring into a store doubles every keystroke for nothing.
- **Ephemeral UI state** — a modal flag in a global store couples unrelated components to one toggle.
- **Anything derivable** from existing state — derive at render time instead of storing the result.

```typescript
// VIOLATION: server data copied into the global store — two sources of truth
const { data } = useMembersQuery();
useEffect(() => { if (data) dispatch(setMembers(data)); }, [data]);

// CORRECT: readers consume the cache layer directly; the store never sees server data
const { data: members } = useMembersQuery();
```

**Credentials are not ordinary client state.** Where the project holds an auth token, follow its existing storage decision exactly and never relax it — in particular, never move a token into web storage to "make it survive a refresh". Identity (user, role, permission set) may persist; a token's storage location is a security decision the project already made. See the `hipaa` skill for the sensitive-data side of browser storage.

**Mutable containers need fresh identities.** `Map`, `Set`, and normalized state are mutable — mutating in place breaks change detection in React and in most stores. Always write a new container.

## Persistence — Three Tiers

**Every screen restores itself on refresh and on browser Back**, with no bespoke per-screen code. Losing a user's filters on F5 is a finding.

Every piece of screen state falls into exactly one tier. Pick by one question: **is it worth sharing or deep-linking?**

| Tier | Examples | Lives in | Survives refresh | Survives Back | Shareable |
|---|---|---|:-:|:-:|:-:|
| **Path** | module, sub-module, active tab, settings section | URL path segment | yes | yes | yes |
| **Query** | filters, search, status, page, size, sort, date range | URL query string | yes | yes | yes |
| **Local ergonomics** | panel open/closed, expanded rows, density, view mode | scoped browser storage | yes | no | no |

**Decision rule:** shareable or deep-linkable → URL (path for structure, query for parameters); purely-local ergonomics not worth a link → storage. **Never storage for filters. Never storage for sensitive data.**

## The URL-State Primitive

**One generic primitive, not several.** The project has (or gets) a single hook over the router's search-params API; table state and feature filters both compose from it. Hand-rolling a second search-params reader alongside an existing one is a finding.

Rules that primitive must satisfy, each a checkable behavior:

- **Omit defaults from the URL** so links stay clean and canonical.
- **Write with `replace`, not push,** for filter and query changes — pushing spams history so Back steps through keystrokes instead of leaving the screen. A *route*-level tab change may push; a *query*-level view change replaces.
- **Reset pagination to page 1** whenever a filter, search, sort, or page-size changes — otherwise the user lands on an empty page 7.
- **Clear deeper params in the same write** when switching a level that invalidates them. Two writes in one tick each build on the render-time snapshot, so the second silently drops the first.
- **Coerce at the edge and never throw.** Everything in a URL is a string; a tampered or unparseable value falls back to its default. An unknown tab key falls back to the first *visible* tab, not to a blank body.
- **Debounce search before writing**, so there is no history or refetch per keystroke.

## Storage Rules

- **Every read and write is wrapped.** Private mode, disabled storage, and quota errors must degrade to in-memory, never crash. Guard for a missing `window`.
- **Version the key namespace** (`app:v1:<screen>:<key>`) so a shape change orphans old keys safely rather than reading a stale structure.
- **Persist the value, not the label** — the stable underlying key, never the displayed text.
- **Prefer per-tab storage** for ergonomics so two tabs stay independent; use durable cross-tab storage only for genuine preferences.
- **Purge on session end and on tenant/context switch**, alongside clearing the data cache.

## Back Navigation

**Back means history-back, not a hardcoded route.** A list's filters live in its URL, so the history entry restores them exactly; navigating to the bare list path silently resets the user to page 1 of the default view, discarding a filter they spent time building.

Provide a fallback path only for the case where there is no in-app history — a deep link, a refresh, or a new tab — where history-back would send the user out of the application entirely.

## Multi-Context / Multi-Tenant Isolation

Where the application serves more than one tenant, clinic, organization, or account context:

- **One source of truth for the active context**, derived from the session, held in one place.
- **One injection point.** The context header or parameter is attached in the single transport seam, never passed as an argument through features. If you find yourself threading a context id into a function signature, the seam leaked.
- **Clear the cache on any context change** — switch or logout. A stale cache is the primary way one context's data appears under another, and it is the single most important isolation rule.
- **Fail loud on a missing context** in an authenticated session; that is a bug, not a state to tolerate.
- **Restore the context before the first request** so there is no window of context-less calls after a refresh.
- **A sub-scope switch is not a context switch** — re-scoping within the same tenant invalidates scoped queries, but does not touch the context identity.
- The client-side header is **convenience; the backend's rejection is the security boundary.**
