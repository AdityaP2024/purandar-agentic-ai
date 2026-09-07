# Performance

Read when: adding a route, rendering a long list, adding an image or font, touching a memoized component, or investigating slowness.

## Measured Targets, Not Vibes

"Fast" is a number. Where the project declares its own budgets, those win; otherwise these are the field-measured thresholds worth holding:

| Metric | Target | What it measures |
|---|---|---|
| LCP (Largest Contentful Paint) | under 2.5s | when the main content becomes visible |
| INP (Interaction to Next Paint) | under 200ms | responsiveness to a click, tap, or keypress |
| CLS (Cumulative Layout Shift) | under 0.1 | how much the page jumps while loading |
| Initial JS, compressed | a declared budget | what must download before anything works |
| Per-route chunk, compressed | a declared budget | the cost of navigating |
| List scroll | 60fps | virtualized long lists |

**A performance claim without a measurement is a finding.** "Optimized" means a number moved; profile before and after rather than asserting an improvement.

## Code Splitting

- **Lazy-load every route except the landing routes.** Lazying the route a user lands on adds a round trip before first paint — it makes the common case slower.
- **Vendor chunks split from app code**, so a deploy does not bust unchanged dependency caches.
- **A primitive genuinely used by most routes stays in the main bundle** — splitting it adds requests without saving bytes. One used by a single heavy route belongs in that route's chunk; check actual usage rather than assuming a shared folder means shared use.
- Suspense fallbacks are **skeletons matching the final layout**, with a short delay so a fast chunk does not flash a placeholder.

## Rendering Cost

| Tool | Use for |
|---|---|
| memo on a component | list and table **row** components |
| memoized derivation | expensive filter/sort/transform over a large list |
| memoized callback | handlers passed to memoized children |

**Memoization has hard prerequisites.** A memoized row is defeated by an inline `columns={[...]}` prop — a new array identity every render. Config arrays passed to memoized primitives are module-level constants or memoized once. **Never pass a fresh object, array, or arrow function as a prop to a memoized child.**

**Blanket memoization is a finding.** It adds indirection and hides real dependency bugs. Memoize for a measured problem or a concrete referential-stability need — nothing else.

**Other render rules:**
- Stable keys from entity ids, never array index.
- Static style objects hoisted out of the component body, not re-created per render.
- Narrow subscriptions: a component subscribes to the one value it reads, not a whole store.
- Shared computations (viewport tier, permission set) computed once at a provider and read from context.

## Virtualization

Any list beyond roughly fifty rows. Also document/thumbnail grids and long dropdowns.

- Give the scroll container an **explicit height**, not `auto`.
- Pin or measure row height once; unstable estimates cause scroll jumps.
- Overscan a few rows so fast scrolling does not show blanks.

## Assets

- **Images:** explicit dimensions to reserve space (this is a CLS fix, not a nicety), lazy below the fold, async decoding, modern formats, SVG for icons and logos.
- **Fonts:** subset to the character sets actually used, self-host where the project does, `font-display: swap` so text paints immediately rather than staying invisible.
- **Never ship a raster asset where a vector works** — it blurs at high pixel ratios.

## Prefetch on Intent

Fetch the route chunk and its data on hover or focus, or when a link enters the viewport. The navigation then feels instant because the work already happened.

## Optimistic Updates

Snapshot, patch the cache, roll back on error, invalidate on settle. The rollback is not optional.

## Scalability of Structure

- A new feature is a new lazy route plus its own slice — **zero impact on existing bundles**.
- Shared code lives in the shared location; cross-feature imports go through it, never feature-to-feature.
- If the project declares a bundle budget, staying inside it is part of done, and a build that exceeds it fails rather than warns.
