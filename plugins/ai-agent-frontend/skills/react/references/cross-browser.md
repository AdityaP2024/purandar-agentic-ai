# Cross-Browser and Platform Compatibility

Read when: writing scroll containers, sticky elements, overlays, inputs, or anything with platform-specific behavior — and before calling a screen done.

Discover the project's support matrix (its browserslist or equivalent) and treat it as the contract. High-risk areas, in order: **scrolling and overflow, sticky positioning, forms, modals, and file upload.**

## Known Failure Modes

| Issue | Guard |
|---|---|
| Sticky headers | need a scroll container with a bounded height **and** an opaque background, or rows show through |
| Momentum scroll and scroll chaining | contain overscroll so an inner scroll does not chain to the page |
| Virtualized lists that jump | give the scroll container an explicit height, not `auto`; measure dynamic rows once |
| Focus ring on mouse click | use `:focus-visible`, not `:focus` |
| Full-height overshoot on mobile | dynamic viewport unit with a static fallback |
| Zoom 80–200% | relative units and spacing tokens; no fixed pixel heights on text containers |
| High-DPI crispness | SVG over raster; intrinsic size must match rendered size |
| Date string parsing | engines differ; construct from explicit parts and format through the platform's internationalization APIs |

## Browser Autofill on Rounded Inputs

**Symptom:** picking a saved credential paints the field pale blue, and the fill **spills past the rounded corners** — a square fill inside a rounded border.

Two separate user-agent behaviors, so the fix is two rules, applied **globally at the theme layer**, never per screen:

| Cause | Guard |
|---|---|
| The radius and border are drawn on the wrapper, but the UA paints autofill on the inner native `input`, which has square corners and fills its whole box | `overflow: hidden` on the wrapper clips the inner fill to the rounded border box |
| The autofill background **ignores `background-color`** outright | a large inset shadow in the field's own color, text color via the text-fill property, plus a long-delayed background transition to outrun the UA's deferred repaint |

Both colors come from **theme tokens**, never a hardcoded hex — or a re-theme leaves autofilled fields stale.

## Polyfill Policy

On an evergreen support matrix, **no blanket polyfills**. A single scoped polyfill only with a documented reason, weighed against the matrix.

## Per-Release Smoke Matrix

Verify the high-risk flows on each supported browser and platform: tables (sort, sticky header, horizontal scroll), scrolling (custom scrollbar, momentum, no chaining), forms (validation display, focus ring, on-screen keyboard not covering the field), modals (focus trap, Escape, background not scrollable), and upload (drag-and-drop, progress, large-file timeout).

Also pass: the narrowest and widest supported viewports, the supported zoom range, and at least one high-DPI device. **The mobile browser is the usual failure point** — check it first, not last.
