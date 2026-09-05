# Accessibility and Keyboard

Read when: building or changing any interactive element, form, overlay, menu, tab strip, table, or navigation — which is nearly every screen.

Every interactive surface is keyboard-operable and screen-reader safe. These are review rules, not aspirations.

## The 13 Standards

| # | Standard | Rule |
|---|---|---|
| 1 | Tab reachability | every interactive element reachable by Tab, in logical DOM order |
| 2 | Arrow-key lists | arrows move within lists, menus and grids (roving tabindex: one item at `0`, the rest at `-1`) |
| 3 | Enter submits/advances | Enter submits a form or advances the field |
| 4 | Escape closes | Escape closes any modal, drawer, menu or popover, and **restores focus to the trigger** |
| 5 | Focus is always visible | never remove the outline; use a `:focus-visible` ring from a token |
| 6 | Focus is trapped in overlays | focus stays inside a modal or drawer until it closes |
| 7 | Async work is announced | loading, success and error reach a live region — polite for status, assertive for errors |
| 8 | Destructive actions confirm | delete/archive/discard require an explicit confirmation step |
| 9 | Required fields are marked | visible marker plus the programmatic required attribute |
| 10 | Errors sit below their field | and are programmatically linked to the input |
| 11 | Icon-only controls are named | an accessible name plus a tooltip; the icon itself is hidden from assistive tech |
| 12 | Skip to content | a skip link reaching the main landmark |
| 13 | Contrast | text and UI meet the project's WCAG level using tokens only |

## Semantic Elements First

`button` for actions, the router's link for navigation, native form controls over click-handling `div`s. Every input has an associated label.

```tsx
// VIOLATION: click-only div — invisible to keyboard and assistive technology
<div className="btn" onClick={onSave}>Save</div>

// CORRECT: a real button is focusable, keyboard-operable, and announced correctly
<button type="button" onClick={onSave}>Save</button>
```

A `div` with `onClick` plus `tabIndex` plus `role="button"` plus key handlers is re-implementing a button badly — use the element.

## ARIA Patterns

| Surface | Roles and attributes |
|---|---|
| Primary nav | a navigation landmark with a label; the active item marked as current page |
| Main region | a main landmark, and the skip link's target |
| Listbox / custom select | listbox with options carrying selected state |
| Data grid | grid with row and cell roles, and column indices where columns are virtual |
| Tabs | tablist / tab / tabpanel with selected state and the control relationship wired |
| Dialog | dialog, marked modal, with a labelling reference and a describing reference |
| Live region | polite for status, assertive for errors |
| Icon button | an accessible name on the control; the icon marked hidden |

**Do not add ARIA where a native element already carries the semantics.** Redundant or wrong ARIA is worse than none — it overrides what the browser already communicates correctly.

## Focus Management

| Concern | Rule |
|---|---|
| Focus trap | modals and drawers trap focus inside until closed |
| Focus restore | on close, focus returns to the element that opened it |
| Visible focus | never remove the outline; `:focus-visible` so mouse clicks do not show a ring but keyboard does |
| Skip to content | first Tab reveals a skip link jumping to the main landmark |
| Roving tabindex | in a list or toolbar, one item is tabbable and arrows move it |
| Route change | focus moves to the new view's heading or main region, not left on a stale control |
| Content removal | when the focused element is removed, focus moves somewhere deliberate — never to `body`, which strands keyboard users at the top |

## Motion and Animation

- **Respect `prefers-reduced-motion`.** Any transition, transform, parallax, or auto-playing motion is reduced or removed when the user has asked for that. This is a WCAG requirement, not a preference — vestibular disorders make unrequested motion genuinely harmful.
- Reduce means **reduce, not break**: a state change still happens, instantly rather than animated.
- **Nothing auto-plays or auto-advances** without a control to pause it.
- Animation never conveys information on its own — if motion communicates a state, that state is also expressed in text or a static mark.

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}
```

## Copy and Naming

- **Every accessible name reads as a real phrase**, never a code or abbreviation.
- A control says exactly what happens; the confirmation says what happened.
- Error text explains what went wrong and how to fix it.

## Verification

- Run the project's automated accessibility assertions on changed components; zero violations is the gate.
- Automated checks catch roughly a third of real issues — **also do a keyboard pass**: reach and operate every control, confirm nothing traps, confirm Escape closes and restores focus.
- Contrast is verified against the project's WCAG level using measured values, not assumed from a component library's defaults. A library's "filled" or "contained" variant frequently fails on light semantic colors.
