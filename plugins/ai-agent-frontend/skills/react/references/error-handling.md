# Error Handling and Loading States

Read when: wiring any API call, writing a `catch`, adding a loading state, or building any screen that can fail — which is every data-driven screen.

Three primitives cover everything: **an error boundary**, **one transport-level error mapper**, and **per-region loading owned by the component that owns the geometry**. Anything more is over-built; anything less leaves white screens.

## Error Boundaries

- **App root** so a crash never shows a blank page.
- **Per route** so a crash in one screen does not kill the shell — navigation and chrome survive, and the recover UI is scoped to that route.
- Boundary logging is **PHI-safe**: no request or response bodies.
- A boundary catches render and lifecycle errors only. It does **not** catch errors in event handlers, async callbacks, or effects' async bodies — those need their own handling.

## One Typed Error

Every transport error becomes one typed application error before any feature sees it, carrying at minimum a **kind** (network, timeout, unauthorized, forbidden, not-found, conflict, validation, server, unknown), the status, and any field errors. A feature hook never receives a raw transport error.

- Detect **transport failures before status codes**, so offline never falls through to "unknown".
- Retry **5xx and network only** — never a 4xx.
- Concurrent auth failures share **one** in-flight refresh, then replay; only a *failed* refresh ends the session.
- The refresh call itself must not route through the interceptor that triggers it, or a failure recurses.

## A Catch Never Names a Cause It Did Not Check

```tsx
// VIOLATION: reports a 500, a dropped connection, and a post-success crash
// all as "wrong password" — costs real debugging time
} catch { toast.error('That password is incorrect.'); }

// CORRECT: one resolver names whatever actually went wrong
} catch (err) { toast.error(errorDisplay(err)); }

// CORRECT: an override only where that status means something specific HERE
} catch (err) { toast.error(errorDisplay(err, { 401: 'That email or password is incorrect.' })); }
```

Resolve display copy **most-specific-first**:

| # | Source | Wins when |
|---|---|---|
| 1 | our copy for a known backend code | the code is mapped |
| 2 | the backend's own message | it sent one |
| 3 | this screen's status override | that status means something specific here |
| 4 | the kind's floor copy | always — guarantees a message is never blank |

Anything that is not a recognized application error resolves to the generic message, so **a crash after a successful request is never reported as a request failure**.

Reserve an override for the status that genuinely means something different on that screen. Everything else needs no argument at all.

## Toast versus Screen

| Kind | Surface |
|---|---|
| validation, conflict, network, timeout | toast, with retry inline |
| forbidden, not-found, server, unauthorized | full error screen or redirect |

## Loading — Four Waits, Four Answers

| Wait | Mechanism | Drawn by |
|---|---|---|
| Route or chunk | Suspense, with a short delay before the placeholder | a page-level skeleton |
| Region first load, shape known | a loading prop | the component itself |
| In-place update (page, filter, sort) | a loading prop | the component dims existing content; it must **not** unmount |
| Any throw | error boundary, per region | the error fallback |

**The four loading rules, each a finding when broken:**

1. **Never wrap a component that owns its own loading state.** A primitive that renders skeleton rows at real column widths and dims during a refetch gets replaced by a wrapper with something worse — and it blanks content the user was reading.
2. **Never gate a whole screen on one query.** Each region owns its own loading, so static chrome and navigation stay usable while data loads.
3. **A placeholder must not drift from the loaded state** — render both through the same layout, swapping only the leaf content. Nothing is re-measured, so a layout change updates both.
4. **A skeleton matches the final layout** so nothing shifts when data arrives.

**Derive the placeholder from the data where possible.** A component taking `data: T | undefined` cannot express the impossible `loading={false}` with no data. Add a separate loading prop only where the component must distinguish "first load" from "refreshing what is already shown".

## Offline

- Detect it, show a persistent indicator, and let queries resume on reconnect.
- Distinguish offline from a server error in the message — "check your connection" is wrong for a 500.

## Error Reporting

- **Where the project has an error-reporting destination, errors reach it**, not only the user — an error nobody records is an error nobody fixes. **Do not add error tracking as part of a feature ticket**: if the project has none, say so in the report as an observation and leave it to the developer.
- **Report PHI-safe**: strip request and response bodies, query strings, and any identifier the compliance profile covers, before anything leaves the client. See the `hipaa` skill.
- Include what makes it actionable: the error kind, the route, a correlation/request id if the backend supplies one.
- **Source maps** are emitted for the reporting tool but not referenced by shipped JavaScript, so the browser never fetches them.

## Mock and Real Layers Reject Identically

Where a project builds screens against a temporary static-data layer, that layer produces the **same typed error objects** the transport mapper produces, pinned by a test. This is the only reason an error path written before the backend exists can be trusted to survive integration.

The swap itself should be **an import line**. If it needs more, the seam leaked and the fix belongs in the seam, not in the feature.
