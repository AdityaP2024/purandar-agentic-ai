# Async, Data Flow, and Race Conditions

Read when: wiring any data fetch, mutation, search box, autocomplete, infinite list, polling surface, or optimistic update.

## Request Efficiency

| Rule | How |
|---|---|
| Stable cache keys | primitives only; an inline object literal is a new identity every render |
| Automatic dedup | many components, one hook, one key → one network request |
| Debounced search | debounce input, then feed the debounced value into the key |
| Guarded queries | an `enabled`-style guard so nothing fires on a null id |
| Pagination without flicker | keep previous data while the next page loads |
| No manual cache writes for server data | invalidate keys after a mutation instead of hand-syncing a store |

## Race Conditions — the Out-of-Order Response

**The failure:** a user types `ann`, then `anna`. Two requests are in flight. The `ann` response returns *last* and overwrites the `anna` results. The UI now shows results for a query the user has moved past, and nothing looks broken — which is why this survives review.

Any surface where a new request can start before the previous one resolves is exposed: search, autocomplete, filter changes, tab switches, dependent dropdowns, and pagination.

**Three correct answers, in order of preference:**

1. **Put every input to the request in the cache key.** A keyed cache layer resolves this by construction — the `ann` response lands under the `ann` key and is simply not what the component reads. This is why the cache-key rule above is a correctness rule, not a performance one.

2. **Cancel the superseded request.** Pass the abort signal the data layer provides through to the transport. An aborted request cannot resolve into a stale write.

3. **Guard the write with a freshness check** where neither is available — capture a request id or the input value, and discard the response if it no longer matches current state.

```typescript
// VIOLATION: last response wins, not latest request — shows results for a stale query
useEffect(() => {
  fetchResults(query).then(setResults);
}, [query]);

// CORRECT (cache layer): the response lands under its own key; a stale key is never read
const { data: results } = useQuery({
  queryKey: searchKeys.list(debouncedQuery),
  queryFn: ({ signal }) => fetchResults(debouncedQuery, { signal }),
  enabled: debouncedQuery.length >= 2,
});

// CORRECT (raw effect): cancel on re-run, and ignore a resolution that lost the race
useEffect(() => {
  const controller = new AbortController();
  fetchResults(query, { signal: controller.signal })
    .then((r) => { if (!controller.signal.aborted) setResults(r); })
    .catch((e) => { if (e.name !== 'AbortError') throw e; });
  return () => controller.abort();
}, [query]);
```

**Never set state from an async resolution without either a cancellation or a freshness guard.** That is a finding.

**An aborted request is not an error.** Filter the abort out of error handling, or every navigation away from a loading screen reports a spurious failure to the user.

## Mutations

- **Invalidate the keys the mutation affects**; do not hand-write the new value into the cache for server data.
- **Optimistic updates follow one shape:** snapshot, patch the cache, roll back on error, invalidate on settle. Skipping the rollback is a finding — a failed mutation must not leave the optimistic value on screen.
- **Guard double-submit.** A submit handler disables its control while in flight; two clicks must not create two records.
- **Mutations that invalidate a list the user is filtered into** should keep the user's filter, not reset the view.

## Polling and Real-Time

- **Poll only what needs freshness**, at the interval the data actually changes; a global short interval is a finding.
- **Stop polling when the surface is not visible** (unmounted, backgrounded tab) and resume on return.
- **A live connection (websocket/SSE) needs an explicit reconnect policy** with backoff, and a defined behavior for messages that arrive while disconnected — silent permanent disconnection is the common failure.
- **Live updates write through the cache layer**, not into component state beside it, or the two diverge.

## Concurrent Rendering

Where the project's React version supports it:

- **`useDeferredValue` for expensive derived views** — the input stays responsive while a large filtered list catches up.
- **`useTransition` for state updates that trigger heavy re-renders** (tab switches over big tables, filter application), so the update does not block typing or clicking.
- **These are not a substitute for virtualization or memoization** — they change scheduling priority, not the amount of work. Reach for them when a measured interaction feels janky, not by default.
- **Never wrap an urgent update** (a controlled input's own value) in a transition; the field will lag behind the keystroke.

## Suspense and Streaming

- A Suspense fallback is a **skeleton matching the final layout**, never a blank or a bare spinner in a page-sized region.
- **Delay the fallback slightly** so a fast resolution does not flash a placeholder for two frames — that reads as a flicker, which is worse than showing nothing.
- Nested boundaries let independent regions resolve independently; one boundary around the whole page reintroduces the "gate the screen on one query" failure.
