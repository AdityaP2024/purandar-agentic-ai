# Responsiveness

Read when: building or changing any layout, page frame, navigation chrome, table, grid, or anything with a width-dependent presentation.

**Rule:** the UI must not break at any supported width, at any device pixel ratio, or at any browser zoom level the project supports. Discover the supported range and the breakpoint values from the project's config — never invent new breakpoint values, and never compare raw pixel widths in JSX.

**Mobile-first, enhance upward.** The narrowest supported width is the base case, not an afterthought.

## Structural Swaps versus Styling

- Use the project's viewport hook for **structural** swaps (table → cards, sidebar → drawer). It subscribes to media queries, so it costs a JS re-render.
- Use responsive style values for **pure styling**. CSS handles those with no re-render.
- **Never** duplicate a component tree and hide one copy with `display: none` — that double-renders and duplicates accessibility nodes.
- Where a shared viewport computation exists, it is computed once at a provider and read from context; a per-consumer media-query subscription multiplies listeners and makes one viewport crossing re-render every consumer separately.

## The No-Break Rules

| Rule | How |
|---|---|
| Flex/grid children must be allowed to shrink | `min-width: 0` on any flex item holding text |
| Long text never expands layout | ellipsis with overflow hidden, or explicit wrapping |
| Wide content scrolls inside its own container | `overflow-x: auto` on the wrapper; the **page** never scrolls sideways |
| Images and media | `max-width: 100%`, `height: auto` |
| Fixed pixel widths in screens | banned — use percentages, fractions, `minmax()`, tokens |
| Emails, IDs, long identifiers | break anywhere rather than overflow |
| Touch targets | meet the minimum touch size on mobile |
| Card grids reflow, never overflow | auto-fitting tracks with a **zero** minimum floor |
| Full-height layouts | the dynamic viewport unit, not the static one — the static one ignores the mobile URL bar |
| Notch and home-bar overlap | apply the platform's safe-area insets to sticky chrome |

## The Bounded-Box Chain

For any screen where an inner region scrolls instead of the page, *every* flex ancestor needs an explicit `min-height: 0`, because a flex item defaults to `min-height: auto` and refuses to shrink below its content.

Break the chain at any link and the symptom appears at the **bottom of the page** — a pagination footer pushed off-screen — not where the missing property is. That distance is what makes it expensive to diagnose.

Equally, a bounded shell uses a **fixed height, not a minimum height**: a minimum still grows with content, and the sticky header scrolls away with it.

The chain is: bounded shell → main region (`flex: 1`, `min-height: 0`, `overflow: auto`) → the screen's own content box → the scrolling primitive.

## Card Grids

- **Fixed max column count:** use an explicit responsive count rather than auto-fill, which packs as many tracks as fit and lets column width drift with the viewport. Keep the track floor at **zero** — that is what preserves the no-overflow guarantee at the narrowest width and at maximum zoom.
- **Equal height across rows:** grid's default stretch equalizes only *within* a row, so row two ends shorter than row one. Explicit row sizing (`grid-auto-rows: 1fr` or equivalent) plus full height on the card fixes it. Content stays top-aligned so extra space falls below the last item rather than spreading items apart.
- **Trade-off, stated:** uniform height means the tallest card sets the size for all. Control it through the **column count**, not by abandoning uniform height.

## Application Chrome

The header and navigation are the highest-risk area on small screens, and belong in a shared shell so every screen inherits correct behavior rather than re-implementing it.

| Element | Wide | Narrow |
|---|---|---|
| Sidebar nav | persistent rail | temporary drawer behind a menu button; closes on route change and backdrop tap |
| Header | full bar: title, search, actions, user menu | compact bar: menu + truncated title + one overflow menu — **never** wraps to a second row |
| Header height | comfortable | reduced, safe-area aware |
| Page title | inline | truncates with ellipsis; must not push controls off-screen (`min-width: 0` on the title box) |
| Tab strips | inline row | horizontally scrollable **inside the strip**; the page never scrolls sideways |
| Bottom actions | inline | sticky bar with the bottom safe-area inset |
| Search | inline field | icon expanding to a full-width overlay |

The narrow header uses the **same tokens** as the wide one — only layout changes, never the design language.

## Definition of Done

- [ ] No horizontal page scroll at the narrowest supported width.
- [ ] Every table or wide grid has a defined narrow-width presentation.
- [ ] Every flex text container allows shrink.
- [ ] Long values truncate or wrap; they never push layout.
- [ ] Content is capped and centered above the widest content width rather than stretching edge to edge.
- [ ] Chrome adapts: nav collapses, header compacts, title truncates, tabs scroll — nothing wraps to a second row or goes off-screen.
- [ ] Dynamic viewport units and safe-area insets applied to the shell and any sticky bar.
- [ ] Verified at the project's locked QA resolutions, if it declares any, and across its supported zoom range — reflow, never clipping.
- [ ] Verified at high device pixel ratio: text crisp, no blurred borders.
