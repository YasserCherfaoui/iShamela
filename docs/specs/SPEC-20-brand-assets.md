# SPEC-020 — Brand Assets, Splash & Download Feedback

**Status:** Implemented · **Design file:** canvas "iShamela UI Redesign" → boards **Brand — app icon & wordmark**, **Splash screen**, **Download feedback — themed snackbar** · **Depends on:** DESIGN-001 tokens, download queue/install registry, SPEC-013
**Goal:** (1) an app icon and splash screen matching the Warm Manuscript identity; (2) the catalog/index made state-correct and idempotent — an installed book can never be downloaded again; (3) immediate, theme-consistent snackbar feedback with live progress when a download starts.

---

## Part A — App icon (brand mark)

- **BR-01** Mark geometry (per Brand board): gold 4-point rosette centered above the open-book glyph on a 24-unit grid; deep-green field `#0E3B30`; glyph strokes paper `#F2E8CF` 1.4–1.7u; rosette `#C6A15B`; inset double gold rule (outer 1.5px @ 85% opacity, inner 1px @ 45%) on the master only — rules drop below 64px renders.
- **BR-02** **No text inside the icon** (no wordmark, no Arabic letters); the lockup (rosette + الشاملة + iSHAMELA) is for splash, About, and store listings only.
- **BR-03** Master is a single SVG (`assets/brand/icon-master.svg`); all rasters are generated from it in CI/script — never hand-edited PNGs.
- **BR-04** Android adaptive icon: background layer = flat `#0E3B30`; foreground layer = rosette+book glyph scaled so it fits the **66% safe zone** (survives circle/squircle masks — see Brand board circle demo). Android 13+ **monochrome/themed** layer = ink single-color glyph (Brand board "Monochrome" tile).
- **BR-05** iOS: full-bleed square renders (no transparency), standard size set via the asset catalog; dark/tinted variants per iOS 18 conventions from the same master (night tile: gold rosette + paper strokes on `#101B17`).
- **BR-06** Web/desktop: favicon 16/32/48, maskable PWA 192/512, Windows/macOS icon sets — same generation script; splash board colors reused for PWA `theme_color` `#0E3B30` and `background_color` `#0E3B30`.
- **BR-07** Usage rules: never recolor, rotate, outline, or add text/effects; clear space around the mark = one rosette width (forbidden example shown struck-through on the board).

## Part B — Splash screen

- **SP-01** Native splash via `flutter_native_splash` (incl. the `android_12:` section): full `#0E3B30` background, centered mark only (no wordmark on the native layer — Android 12 clips to a circle). iOS launch storyboard: same color + centered mark.
- **SP-02** First Flutter frame renders the full splash layout from the Splash board — gold hairline, mark, **الشاملة** (Amiri 40/700 paper), **iSHAMELA** (letter-spaced gold), tagline `مكتبتك في العلوم الشرعية — دون اتصال`, and a 132×3 indeterminate gold bar with caption `يجري تجهيز المكتبة…` — shown **only while** startup work (DB open, catalog check, settings load) is pending.
- **SP-03** Native→Flutter handoff is seamless: identical background color and mark position, so the wordmark/tagline appear to fade in around a stationary mark (250 ms fade; respect `disableAnimations`). No double-splash flash.
- **SP-04** Splash → Catalog transition: 200 ms fade-through once startup completes; hard budget — if startup finishes < 400 ms, still hold the full splash to 400 ms total to avoid a flash-frame, never longer than the work itself + 400 ms.
- **SP-05** No dark-mode variant needed for the splash itself (`#0E3B30` works for both); status/navigation bar colors set to match during splash on Android.
- **SP-06** The splash performs **no network work** and never blocks on catalog sync (sync stays a background tick per current behavior).

## Part C — Index/catalog download idempotency

Single source of truth = install registry + download queue. All affordances are **derived state**, never widget-local flags.

- **DL-01** Book affordance mapping everywhere a book row renders (Catalog browse/search, BookListPage, author pages, Library-adjacent surfaces):
  | Derived state | Trailing affordance | Tap on affordance |
  |---|---|---|
  | installed | **مثبّت** chip | none (row tap opens Reader) |
  | queued/downloading/verifying/installing | progress ring (٪; indeterminate ring while queued/verifying) | pause ⇄ resume toggle |
  | paused | progress ring, gold arc | resume |
  | not installed, downloadable | download button | enqueue |
  | not downloadable | dashed muted row, no affordance | none |
- **DL-02** **An installed book exposes no download entry point anywhere**: no download button, disabled (not just unchecked) in select mode with the مثبّت chip shown, excluded from تنزيل الكل / تنزيل المحدد counts and from the confirm sheet's size math, and its row in Downloads→المكتملة offers إعادة التنزيل only through the existing explicit redownload action (unchanged, that is a deliberate reinstall, not a download).
- **DL-03** Enqueue is **idempotent at the service layer**: `enqueue(bookId)` is a no-op returning the existing task if the book is installed or already in the queue in any non-terminal state. UI taps are additionally debounced (300 ms) so a double-tap creates one task and one snackbar.
- **DL-04** Defensive guard: if a stale UI or deep link still triggers enqueue for an installed book, the service rejects it and the UI shows snackbar `«{title}» مثبّت بالفعل` with action **افتح**.
- **DL-05** All row affordances update **reactively** from queue/registry streams (install completes elsewhere → the visible row flips to مثبّت without refresh; cancellation flips it back to the download button).
- **DL-06** Bulk flows (تنزيل الكل, select mode) compute their target set as `downloadable ∧ ¬installed ∧ ¬queued` at confirm time, re-validated at execution time (books installed between confirm and start are skipped silently).

## Part D — Themed download snackbar

Replaces the stock Material snackbar for download events; visual per the DownloadSnackbar board.

- **SB-01** Style: floating, radius 14, margin 16, above the bottom nav (or bottom safe area on pushed pages); background = `green900` in light/sepia chrome, raised `#1B2A24` in night; text paper, action **عرض** in `goldSoft`; contains a 3px progress bar (track `#1E5040`, fill `goldSoft`) + caption `٪ · x من y م.ب`. RTL layout; download glyph leading.
- **SB-02** On successful enqueue: show `جارٍ تنزيل «{title}»`; bar indeterminate until `bytesTotal` known, then determinate, **streaming live progress** from the queue while visible. Action **عرض** → Downloads tab (النشطة).
- **SB-03** Duration 4 s; a new enqueue while visible replaces content and coalesces the label: `جارٍ تنزيل {n} كتب` (count = currently active+queued), same عرض action.
- **SB-04** If the download completes while the snackbar is visible, it morphs in place to `اكتمل تنزيل «{title}»` with action **افتح** (3 s more). If it fails while visible: error variant — leading glyph and action tinted `error`-on-dark (`#E08A76`), text `تعذر تنزيل «{title}»`, action **إعادة** re-enqueues.
- **SB-05** The DL-04 "already installed" snackbar uses the same component without a progress bar.
- **SB-06** One snackbar host app-wide (queue events, not per-screen); it must not overlap the reader's bottom chrome — in the Reader it rises above the page bar. Never shown for background-completed downloads when the app resumes (Downloads tab badge covers that).
- **SB-07** Accessibility: content announced via semantics on show and on the completed/failed morphs; progress not announced continuously. Honors reduced motion (no slide, fade only).

## Acceptance criteria

1. Icon renders crisply at 48–512 on Android (circle + squircle masks keep the glyph whole), iOS, web favicon, and Android 13 themed mode; all produced by the generation script from one SVG.
2. Cold start: no white flash, no double splash; mark stays fixed through native→Flutter handoff; app is interactive ≤ startup work + 400 ms.
3. Tapping download on صحيح مسلم: button becomes an indeterminate ring within one frame, snackbar appears with title, ring and snackbar both show live ٪ once size is known; double-tapping produced exactly one queue task.
4. An installed book shows no download affordance in Catalog browse, Catalog search, BookListPage, author page, or select mode; تنزيل الكل over a category with 3 installed of 10 confirms "٧ كتب".
5. Forced enqueue of an installed book (test hook) → rejected + "مثبّت بالفعل" snackbar with working افتح.
6. Snackbar matches theme in light and night chrome (golden tests) and morphs correctly on completion and failure.

## Tests

Unit: derived-state mapper (all queue statuses), idempotent enqueue (installed/queued/racing), bulk target-set recomputation, snackbar coalescing reducer. Widget: affordance table golden per state, snackbar variants + morphs, reduced-motion path. Integration: enqueue→progress→complete flips row to مثبّت and Library gains the book; splash handoff screenshot test per platform. Script test: icon generation output inventory matches BR-04/05/06.

## l10n keys

`downloadingBook, downloadingNBooks, viewDownloads, downloadCompleteSnack, open, downloadFailedSnack, retry, alreadyInstalled, preparingLibrary, appTagline`

## Open questions

- OQ-1: tagline final wording (`مكتبتك في العلوم الشرعية — دون اتصال` proposed) — Ladj to confirm before store assets are cut.
- OQ-2: should tapping the progress ring pause (as specced, DL-01) or open Downloads? Pause matches the Downloads card's primary action; flag if you prefer navigation.