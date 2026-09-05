# Permission Gating, Dates, and Client-Side Security

Read when: gating any UI on permissions, rendering a date or number, or touching anything security-relevant on the client.

## Permission Gating

Gate on **permission keys, never on role names** — roles are backend data that changes without a deploy; a role-to-permission matrix built on the client is always a finding.

| Scope | Tool |
|---|---|
| A single element | a gate component wrapping just that element |
| A section or region | a gate supporting one/any/all of a key set |
| A route | a route guard |
| Imperative, inside a component | a permission hook |
| Imperative, outside React | a plain function over the permission set |
| Nav and config | a filter that drops entries the session cannot see |

**Route guard behavior is three distinct cases:**
- **Unauthenticated** → redirect to login, **preserving the intended URL** so the user lands where they were going after signing in.
- **Authenticated but forbidden** → render a forbidden **screen**, not a redirect. A redirect loses the fact that the resource exists and the user simply lacks access.
- **Authenticated and permitted** → render.

**Hidden versus disabled:** hide an action the viewer can never earn; disable one that is only temporarily unavailable, and say why. Showing a greyed control with no path to enabling it is noise; hiding a temporarily-blocked one is confusing.

**A container whose every action is filtered out disappears entirely**, rather than leaving a menu that opens onto nothing.

**Performance is part of the contract:** membership resolves through an O(1) set lookup; the check function is referentially stable so memoized children are not forced to re-render; a single-key subscription re-renders only when *that* grant flips. Scanning an array for a permission, or subscribing a whole component to the auth store just to make one check, are both findings.

**Unknown permission keys are preserved, never dropped** — a backend-created permission must flow through with zero frontend change.

**Client-side gating is UX, not security.** The backend authorizes every request regardless. Never rely on a hidden control to protect data.

## Date, Time, and Formatting

- **One module owns date handling**; it is the only place the date library is imported. A component that imports the date library directly, or calls `new Date(string)` for display, is a finding.
- **Store and transport in UTC**; convert only at the display edge, to an explicit timezone.
- **Format tokens live in a config constant**, never inline in a component. A component passes a named format key to a helper; it never spells out a format string.
- **Never add or subtract fixed hour offsets** for timezone or DST — the timezone layer handles it.
- **Use the platform's internationalization formatters** for dates and numbers; engine-specific date parsing differs between browsers.
- Where the application spans locations in different timezones, a display timezone is a parameter, not a global assumption.

## Client-Side Security

The `hipaa` skill governs sensitive-data handling in full; these are the general client-side rules that apply regardless of domain.

- **Never render unsanitized HTML from user or API input.** Where raw HTML is genuinely required, sanitize it through the project's sanitizer. This is the primary client-side injection vector.
- **Secrets never reach the client bundle.** Only the build's public-prefixed variables are exposed, and a real secret must never be one of them. Verify by searching the built output, not by assuming.
- **Never log a credential or a token**, including in an error report.
- **Respect the project's content-security policy** — inline scripts and arbitrary external origins will be blocked, so do not introduce them.
- **Destructive actions are soft where the project has decided so** — an archive flag rather than a hard delete, with the list filtered accordingly.
- **Payment and credential fields go through the provider's own hosted element** where one exists; raw card data must never enter application state.
- **An idle timeout ends the session** where the project defines one, warning before it fires, and clearing the cache and persisted state on the way out.
- **Dependencies are audited**; a known high-severity advisory in a shipped dependency blocks release. Adding a dependency at all requires the new-dependency gate.
