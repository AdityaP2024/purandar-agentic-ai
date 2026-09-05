---
name: react
description: read this when implementing or reviewing React/TypeScript frontend code — the router card for the frontend engineering standards; it carries the always-on rules and routes to reference files for responsiveness, accessibility, theming, state and persistence, async and race conditions, error handling, performance, forms and API contract, testing, cross-browser, permission gating, and code quality
---

# React / TypeScript Engineering Standards

Router card for the frontend-react agent. `shared-standards` applies first; this card adds the React/TypeScript specifics. Client-side PHI rules (console, browser storage, URLs, route params, analytics, error reporting) live in the `hipaa` skill — load it for any PHI-touching screen; nothing here restates those rules.

**How this card works.** The rules below are **always on** — they apply to every task and you never need to look them up. Everything else lives in reference files you **read on demand** using the routing table. Read a reference file when its trigger matches; do not read files a task does not touch, and do not read all of them by default.

**How to read a rule.** Every rule is a *checkable finding*, not advice. Where a rule names a value, that value is an example of the shape — discover the project's own value and use it. **This card pins NO library, NO version, and NO directory layout.**

---

## Routing Table — Read On Demand

Paths are relative to this skill's directory (`${CLAUDE_PLUGIN_ROOT}/skills/react/`).

| Read this file | When the task involves |
|---|---|
| `references/theme-and-tokens.md` | any styling; adding a status, icon, route, or permission; anything rendering an enumerable set; building on a shared primitive |
| `references/state-and-persistence.md` | deciding where state lives; filters, search, sort, pagination; refresh/Back survival; multi-tenant or multi-context isolation |
| `references/async-and-data.md` | any fetch or mutation; search or autocomplete; infinite lists; polling or real-time; optimistic updates; anything where a response can arrive out of order |
| `references/forms-and-contract.md` | consuming tech-spec Section 5; any form; wiring a service or hook; file upload |
| `references/error-handling.md` | any API call; writing a `catch`; any loading, empty, or error state; error reporting |
| `references/responsiveness.md` | any layout, page frame, navigation chrome, table, or grid; anything with a width-dependent presentation |
| `references/accessibility.md` | any interactive element, form, overlay, menu, tab strip, or navigation — nearly every screen |
| `references/performance.md` | adding a route; long lists; images or fonts; touching a memoized component; investigating slowness |
| `references/code-quality.md` | structuring a component; typing anything; logic that loops, looks up, sorts, or traverses |
| `references/testing.md` | writing any test; deciding whether a screen is done |
| `references/cross-browser.md` | scroll containers, sticky elements, overlays, inputs; before calling a screen done |
| `references/security-and-gating.md` | gating UI on permissions; rendering dates or numbers; anything security-relevant on the client |

**Minimum reads for a typical screen:** a data-driven screen with a form touches `async-and-data`, `forms-and-contract`, `error-handling`, `responsiveness`, `accessibility`, and `testing`. A pure styling change may need only `theme-and-tokens`.

**Do not apply a rule from memory when its reference file is relevant to the task — read the file.** These rules carry exact thresholds and failure modes that paraphrase badly.

---

## Always-On Rules

These apply to every frontend task without a lookup.

### 1. Discover the Stack First — Never Assume

Before writing any code, discover the project's actual stack from `package.json` and the existing source:

| Fact | Where to Discover |
|---|---|
| Data-fetching / cache library | `package.json` dependencies plus existing service and hook files |
| Global state store | `package.json` plus existing store/provider setup |
| Form library | `package.json` plus existing form components |
| Router | `package.json` plus existing route definitions |
| Styling system | existing components (CSS modules, styled components, utility classes, UI kit) |
| Design-token source | theme/token module, CSS custom properties, or a design-tool export |
| Breakpoint values | the theme/config that declares them — never invent new ones |
| Icon system | existing icon imports or a semantic icon registry |
| Date/time library and format constants | `package.json` plus an existing datetime util module |
| Test runner and component-test library | `package.json` scripts plus existing test files |
| Lint rules that constrain code shape | `eslint.config.*` — restricted imports, folder naming, boundaries, function size |

**Follow the project's existing conventions exactly.** Introducing a parallel convention alongside an existing one is a finding, even when the new one is arguably better. Where the tech-spec is silent, the consuming repo's existing code IS the convention.

**Only build what the project needs.** A capability the project has deliberately not adopted — internationalization in an English-only product, dark mode in a single-theme product, offline support in an always-connected tool — is **not** added because this card mentions it. Discover what the project does, and match it. Introducing an unrequested capability is scope creep and a finding.

**When this card names infrastructure the project does not have.** Many rules here are written as "through the project's X" — a field wrapper, a key factory, a token source, a registry, a shared primitive, a transport seam, an error reporter. Where the project HAS X, use it; bypassing it is a finding. Where the project does NOT have X, the rule still names an **outcome** — a label and error bound to an input, a stable cache key, a consistent value, one place a call goes out. Achieve that outcome with what the project already has, plainly and locally, and **name the missing piece as an observation in your report**. Building the infrastructure itself inside a feature ticket is scope creep and a finding: the developer decides whether the project adopts it.

**The rule of thumb:** this card describes the outcomes a strong frontend must reach, and the shapes that reach them. Where an outcome and a project's existing convention appear to conflict, the convention wins for *how* and the outcome still holds for *what* — and if they genuinely cannot both hold, that is a conflict to surface, not to resolve silently.

**Monorepo dependency isolation.** Under strict `node_modules` layouts, a package resolves only the dependencies it declares itself — transitive deps of a shared package are NOT inherited. When a feature package uses a library for the first time, the dependency must be added to *that* package's manifest at a version matching the rest of the workspace.

### 2. Section 5 Is Verbatim

Section 5 of `docs/tickets/<KEY>/tech-spec.md` is drop-in: endpoint signatures, shapes, names, error mappings, field bindings, exactly as written. **Any gap or ambiguity is a stop-and-surface to the developer — NEVER a guess.** An invented name that happens to look plausible is the worst defect this agent can produce. Details in `references/forms-and-contract.md`.

### 3. No Literals Where a Token Exists

Every color, spacing, radius, shadow, type size, and breakpoint resolves through the project's token source. A raw hex, a raw `px`, or a magic number in a screen is a finding. Details in `references/theme-and-tokens.md`.

### 4. State Lives in Its Narrowest Correct Scope

Server data in the project's cache layer (never copied into a global store); form values in its form library; ephemeral UI state in the component; shareable view state (filters, search, sort, page, active tab) in the URL. Where the project has no such layer, the outcome still holds — one owner per piece of state, and no second copy that can drift. Details in `references/state-and-persistence.md`.

### 5. Every Async Surface Renders Loading, Empty, and Error

Deliberately, tied to the tech-spec Section 9 edge cases. **A screen that only handles the happy path fails review.** Details in `references/error-handling.md`.

### 6. Never Set State From an Async Resolution Without a Guard

Either the cache layer keys it, the request is cancelled, or a freshness check discards the stale write. Out-of-order responses are the most common silent data bug in React. Details in `references/async-and-data.md`.

### 7. Keyboard and Screen-Reader Operable

Semantic elements (`button` for actions, the router's link for navigation, native form controls over click-handling `div`s), every input labeled, every interactive element reachable and operable by keyboard, focus visible and never trapped unintentionally. Details in `references/accessibility.md`.

### 8. Layout Never Breaks

At any supported width, pixel ratio, or zoom level. Breakpoints are discovered, never invented. The page never scrolls sideways. Details in `references/responsiveness.md`.

### 9. Assemble, Never Fork

Build from the project's shared primitives and registries **where they exist**. A per-screen copy of a shared table, form, or dialog is a finding — extend via an optional config field instead. Where a project has no shared primitive for what you need, build the screen plainly and note the candidate in the report; **do not build a framework inside a feature ticket**. Details in `references/theme-and-tokens.md`.

### 10. Measure Before Claiming Optimized

Memoize for a measured problem, not by default. A performance claim without a measurement is a finding. Details in `references/performance.md`.

### 11. Test Behavior, and Cover the Scenarios

Assert what the user sees and does, never internal wiring. Every AC maps to at least one test. **Line coverage is not scenario coverage** — walk the catalog for the kind of thing you built. Never weaken a test to make it pass. Details in `references/testing.md`.

### 12. Report Failures Honestly

Run the project's own test script and report output verbatim, failures included. Never claim done over a failing test.

---

## Self-Review Checklist

Run this after the work is written and before reporting. Each line is pass/fail. **Any failure means fix and re-run the whole list.** Where a line's reference file is relevant to what you built, read that file and check against it in full rather than from memory.

**Contract and correctness**
- [ ] Section 5(e) names, paths, and cache keys match the spec's tables exactly.
- [ ] Every consumed 5(d) row is implemented per its exact label and asserted by a test.
- [ ] Every 5(f) binding uses the exact request path and named transform; no extra or renamed fields.
- [ ] Every 5(b) rule for in-scope fields is mirrored client-side.
- [ ] No async resolution writes state without a cache key, a cancellation, or a freshness guard.
- [ ] Mutations invalidate rather than hand-sync; optimistic updates roll back on error.
- [ ] All API calls route through the project's existing transport seam; no second client introduced.

**Structure and types**
- [ ] Stack facts came from `package.json` and existing code — nothing assumed or pinned.
- [ ] No parallel convention introduced alongside an existing one.
- [ ] No capability added that the project has not adopted.
- [ ] No component fetches, transforms, renders, and owns unrelated concerns at once.
- [ ] No `any` on domain data; view states are discriminated unions; API types live in one place.
- [ ] Strict-index results are narrowed, never silenced with `!`.

**Presentation**
- [ ] No hex, raw px, or magic number in a screen — every value is a token.
- [ ] No forked copy of a shared primitive; capabilities enabled by presence, not booleans.
- [ ] Enumerable sets (statuses, icons, routes, permissions) read from the project's registries where it has them; none hardcoded in a screen that duplicates an existing registry.
- [ ] Layout holds at the narrowest and widest supported widths and across the supported zoom range; no horizontal page scroll.
- [ ] Every flex text container allows shrink; wide content scrolls in its own container.
- [ ] Navigation chrome adapts at narrow widths without wrapping or going off-screen.

**States and errors**
- [ ] Every async surface renders loading, empty, and error deliberately.
- [ ] No component with its own loading state is wrapped in a loading gate; no screen is gated on one query.
- [ ] Every `catch` names only a cause it actually checked.
- [ ] Where the project has error reporting, errors reach it with sensitive fields stripped (reporting is not added by a feature ticket).

**Accessibility**
- [ ] Every interactive element is a semantic element, keyboard-reachable and keyboard-operable.
- [ ] Overlays trap focus, close on Escape, and restore focus to their trigger.
- [ ] Every input has a label; every error is programmatically linked to its input.
- [ ] Every icon-only control has an accessible name; decorative icons are hidden.
- [ ] Motion respects `prefers-reduced-motion`.
- [ ] The project's automated accessibility assertions pass on changed components.

**Persistence and security**
- [ ] Filters, search, sort, page, and active tab survive refresh and Back via the URL.
- [ ] No filters and no sensitive data in browser storage; every storage access is wrapped.
- [ ] Gating is on permission keys, never role names.
- [ ] No unsanitized HTML rendered from user or API input; no secret in the client bundle.

**Testing and delivery**
- [ ] Every in-scope AC maps to at least one test; unchecked ACs carry stated reasons.
- [ ] The scenario catalog rows matching what was built are covered.
- [ ] No test or assertion was weakened, skipped, or disabled.
- [ ] The `package.json` diff contains no dependency without an approved new-dependency gate.
- [ ] The change list touches no backend file.
- [ ] Test output reported verbatim, failures included.
