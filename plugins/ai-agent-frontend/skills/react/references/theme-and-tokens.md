# Theme, Design Tokens, and Config Registries

Read when: writing any styling, adding a status/icon/route/permission, or building a screen that renders an enumerable set.

## Design Tokens

**Every color, spacing, radius, shadow, font size, and breakpoint comes from the project's token source.** A raw hex, a raw `px`, or a magic number in a screen is a finding. One token change must propagate app-wide; a literal is what breaks that guarantee.

| Value | Comes from |
|---|---|
| Color | the palette token (`primary.main`, `text.secondary`, a semantic ramp step) |
| Spacing / gap / padding | the spacing scale, via its unit multiplier |
| Border radius | a named radius token |
| Elevation / shadow | a named shadow token |
| Type size, weight, line-height | a named type variant — never a literal `fontSize` |
| Breakpoint | the declared breakpoint keys, by name |

```tsx
// VIOLATION: literals — a re-theme leaves this element stale
<Box sx={{ padding: '16px', borderRadius: 8, color: '#1A73C8' }} />

// CORRECT: every value is a token the theme owns
<Box sx={{ p: 2, borderRadius: `${radii.sm}px`, color: 'primary.main' }} />
```

**Beware token scales that multiply.** When a styling system's shorthand multiplies a base unit (a `borderRadius: 1` meaning "1 × the base radius"), a bare number silently renders the wrong value. Always pass the named token explicitly. If the project has a lint rule forbidding bare numeric values for such a property, that rule is the contract — do not work around it.

**Semantic ramps, not saturated mids.** Status and feedback surfaces (toasts, alerts, badges) take a tinted background, a darker text/icon step, and a mid border from the same semantic ramp. Flooding the surface with a palette's saturated `main` step is both off-design and a frequent contrast failure — a library's "filled" variant commonly fails WCAG AA on success and warning colors. Measure rather than assume.

**Style at the theme layer, not the call site.** A component-level style override that every call site would otherwise repeat belongs in the theme's component overrides. A screen styling its own toast, chip, or input is a finding — it guarantees drift between screens.

**Where the project constructs a runtime theme object, it is a module singleton** — created once at import, never rebuilt per render. Recreating it inside a component re-serializes every style on every render. A project whose tokens are plain CSS custom properties or compile-time utility classes has no such object and needs none; the token rules above still apply.

**Fluid type over breakpoint jumps.** Where the project scales type across viewports, prefer a fluid function computed once at module load over media-query steps — the browser handles interpolation in CSS with no JS on resize. **Body text never renders below 16px**: smaller triggers zoom-on-focus on iOS and fails legibility.

**Multi-theme discipline.** If the project declares more than one theme, every color resolves through a token defined in the base theme and redefined per theme. A color whose only definition lives inside one theme's block renders unstyled in the other. If the project is deliberately single-theme, do not introduce a second one.

## Config Registries — Declare Once, Read Everywhere

Anything enumerable — routes, navigation, permissions, statuses, icons, shortcuts, sensitive-field rules, table columns, form fields, tabs — is **declared once in config and read by screens**. A screen that hardcodes one of these is a finding.

| Registry | Consumed by | Adding an entry means |
|---|---|---|
| Routes / paths | router, nav, links | one config entry, no screen edit |
| Navigation menu | sidebar, breadcrumbs | one config entry |
| Permission keys + matrix | route guards, gated elements, action gating | one config entry |
| Status → `{label, color, variant}` | status chips, filter dropdowns | one config entry, zero component edits |
| Icon semantic name → glyph | every icon consumer | re-skin globally in one place |
| Sensitive field → `{mask, revealPermission}` | table cells, detail views | one rule, one audit point |
| Constants (timeouts, page sizes, debounce, limits) | hooks, api, tables | one place to tune |

```ts
// VIOLATION: a switch returning presentation — every new status edits component code
switch (status) {
  case 'ACTIVE': return <Chip color="green" label="Active" />;
  case 'PENDING': return <Chip color="orange" label="Pending" />;
}

// CORRECT: data, not control flow — a new status is one registry row
const meta = STATUS_REGISTRY[status];
return <Chip color={meta.color} variant={meta.variant} label={meta.label} />;
```

- **Registry colors are token keys, never hex.** A registry storing a literal defeats theming just as a screen literal does.
- **Unknown keys fail soft.** A lookup for a value the registry has never seen renders something sane (the raw key, a neutral style) rather than crashing the row it sits in. A backend that adds an enum value must produce a slightly plain chip, not a blank screen.
- **Icons go through a semantic layer.** Components reference a role (`'patient'`, `'billing'`), never an icon library's file name. That indirection makes a global re-skin one edit. When mapping a name to a glyph, match the **design**, not the word — a plausible-sounding icon name is frequently the wrong glyph. A wrong name should be a build error, not a silent fallback.
- **Copy lives beside what it names.** Labels, headers, empty-state text, and action names are plain strings in the config entry or at the call site, so a wording change is a one-line edit.

## Config-Driven Primitives — Assemble, Never Fork

Where many screens render the same *kind* of surface (list/table, form, detail panel, tab strip), the project builds **one** primitive taking a config object plus runtime props. A screen describes its instance as data; it never hand-builds the markup, and never forks the primitive.

**The split that keeps call sites short:** config is the surface's *identity* (columns, row id, actions, empty copy) and never changes at runtime; props are its *state* (rows, loading, selection, pagination) and change constantly.

**Capabilities are enabled by presence, never by a boolean flag.**

| Capability | On | Off |
|---|---|---|
| Pagination | pass the pagination state object | omit it |
| Selection | pass the selection set + change handler | omit them |
| Infinite scroll | pass the load-more handler | omit it |
| Sorting | pass sort state + sort handler | omit them |
| Row actions | declare an actions column | don't declare one |

A flag can contradict its data — what does `hidePagination={false}` mean when no pagination state was passed? Presence cannot reach that state, and the type system can enforce completeness when the state *is* there. **A new capability is a new optional object, never a new boolean.**

**When a design needs something the primitive cannot express, add an optional config field — never fork the component.** A per-screen copy of a shared table is the most expensive mistake in this category; two copies drift within days.

**Rows stay data; columns own presentation.** A column's cell renderer receives the typed record and returns a node. Pre-rendering rows into markup before they reach the primitive makes them unsortable, unexportable, and untestable.

**Promote a repeated markup pattern to a shared component once it has two or three real consumers** — a judgment call, not a threshold to apply mechanically. Promote it where the project keeps shared components, never into a primitive's internal folder, and never pre-emptively on the first occurrence.
