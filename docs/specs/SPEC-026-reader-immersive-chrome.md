# SPEC-026 — Immersive reader chrome

**Status:** Implemented · **Depends on:** SPEC-009, SPEC-012 · **Deliverable:** reader chrome that hides while reading, the way Apple Books does

## Purpose

Let the page fill the screen. A tap shows or hides the reader chrome, and turning a page hides it. `pages.body` is not modified. No new packages.

## 1. What counts as chrome

Chrome is all of the following, together:

- The reader app bar (back, title, search, bookmark, TOC, book card, overflow).
- The in-book search hits strip, when it has results.
- The wide TOC and book-card panes (SPEC-009). Their open/closed flags stay as the user left them; hiding chrome only stops drawing them.
- The bottom page bar (scrubber, previous, page pill, next).

Narrow TOC and book-card sheets are routes. They stay until dismissed.

The hidden flag is **not** persisted. Opening a book always starts with chrome visible. Leaving the reader restores the system status bar.

## 2. Tap

A short primary-button tap on the page body toggles chrome.

Ignore the tap when any of these is true:

- The pointer moved more than **18** logical pixels (page swipe or scrolling).
- The press lasted more than **300** ms (long-press / text selection).
- A non-collapsed text selection was already active at pointer-down. That tap only clears the selection.
- The target is a note badge (SPEC-012). The badge keeps its edit action.

## 3. Page turn

After the book is open, chrome hides when the page index **changes**:

- `PageView` swipe (`paged_h`, `paged_v`)
- Previous / next
- Jump sheet, TOC, or a search hit

The same index does not hide chrome. Restoring the saved page on open is not a page turn. Showing or hiding chrome does not change the page: the reading column keeps its place when the wide side panes appear or disappear.

The scrubber stays up while the thumb is down, including while the index is changing, and hides on release.

Scrolling inside a single print page does not hide chrome.

## 4. Continuous mode

`continuous_v` has no page swipe. A user scroll of the continuous list whose accumulated delta reaches **48** logical pixels hides chrome. A scroll inside one print page does not. The scrubber rule in §3 still applies.

## 5. Motion and system UI

Bars animate closed and open in **200** ms and the page area grows into the space they leave. `MediaQuery.disableAnimations` makes the change instant.

On mobile, hiding chrome hides the status bar (`SystemChrome`, manual overlays with the top overlay off). The home indicator / navigation bar stays. Showing chrome, and disposing the reader, restores `SystemUiMode.edgeToEdge`. Web does not call `SystemChrome`.

While chrome is hidden, the page body respects the top and bottom view padding so text stays clear of the notch and the home indicator. The reader background still fills the screen.

## 6. Semantics

The page exposes a localized label: hide controls when chrome is visible, show controls when it is hidden. No new visible button. Accessibility activation toggles chrome the same way a tap does, and still respects an active text selection.

## 7. Acceptance criteria

- [ ] Opening a book shows chrome.
- [ ] A short tap on the page hides chrome; the next tap shows it.
- [ ] A tap does nothing to chrome when a text selection was already active, or when it hits a note badge.
- [ ] A page-index change hides chrome. Reporting the same index does not.
- [ ] Showing chrome again leaves the reader on the page reached while chrome was hidden.
- [ ] Dragging the scrubber keeps chrome visible until release, then hides it.
- [ ] Continuous-list scroll of 48px or more hides chrome. Scrolling inside one print page does not.
- [ ] The hidden flag is not written to settings. Leaving the reader restores edge-to-edge system UI.
- [ ] `flutter analyze` is clean. Unit tests cover the state machine in §2–§4.

## Out of scope

- Persisting the hidden flag.
- A settings toggle for this behavior.
- Changing page layout, print page numbers, or `pages.body`.
