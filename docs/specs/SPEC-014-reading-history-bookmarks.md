# SPEC-014 — Reading History & Bookmarks

**Status:** Implemented · **Depends on:** SPEC-004, SPEC-005, SPEC-009, SPEC-010, SPEC-012, SPEC-013 · **Design:** [`DESIGN-002`](../design/DESIGN-002-history-bookmarks.md) M-F1 (F1 + F2 only) · **Deliverable:** `state.sqlite` v6 tables + Library history screen + reader bookmark toggle / pane tab

## Purpose

Give readers a **session history** (what they opened, how far they got) and **page bookmarks** (marks distinct from SPEC-010 text annotations). Visuals reuse DESIGN-001 tokens/components. No new product surface beyond DESIGN-002 §2–3.

## Relationship to existing specs

| Prior | Change |
|---|---|
| SPEC-005 `reading_state` | **Unchanged** — still the last-page restore source of truth |
| SPEC-005 sketched `bookmarks(book_id, page_id, note, …)` | **Superseded** by this spec’s `bookmarks` schema (`label` instead of `note`; notes stay SPEC-010 `text_notes`) |
| Library continue-reading hero (DESIGN-001 / SPEC-013 UX) | Hero becomes latest `reading_history` row (`LIMIT 1`); eyebrow gains link to full history |

## 1. Storage (`state.sqlite` migration v5)

Bump `PRAGMA user_version` to **6** in `StateDatabase` (v5 already used for `installed_books.page_count`). Allowed dependency list: existing Flutter / `sqlite3` only — **no new packages**.

```sql
CREATE TABLE reading_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id INTEGER NOT NULL,
  part TEXT,
  page_id INTEGER NOT NULL,          -- = pages.id
  print_page INTEGER,                -- nullable; NEVER invent
  section_title TEXT,                -- nearest TOC title at update; nullable
  opened_at INTEGER NOT NULL,        -- ms epoch
  closed_at INTEGER                  -- ms epoch; null while session open
);

CREATE INDEX reading_history_opened ON reading_history(opened_at DESC);
CREATE INDEX reading_history_book ON reading_history(book_id, opened_at DESC);

CREATE TABLE bookmarks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id INTEGER NOT NULL,
  part TEXT,
  page_id INTEGER NOT NULL,          -- = pages.id
  print_page INTEGER,                -- nullable; NEVER invent
  label TEXT,                        -- optional user rename; null = derive display
  created_at INTEGER NOT NULL,
  UNIQUE(book_id, part, page_id)
);

CREATE INDEX bookmarks_book ON bookmarks(book_id, created_at DESC);
```

`part` in the UNIQUE key: treat SQL `NULL` as equal for uniqueness purposes (use `COALESCE(part, '')` in the unique index if needed so two nulls collide).

## 2. Reading history semantics

### Write path (same hook as `upsertReadingState`)

On reader **open** (after book DB opens successfully):

1. Upsert `reading_state` as today.
2. History coalesce: if the newest row for this `book_id` has `opened_at` within **30 minutes** of now, **update** that row (`page_id`, `print_page`, `section_title`, `closed_at=null` or leave open); else **INSERT** a new row with `opened_at=now`, current page fields, `closed_at=null`.

On **page change** (and on dispose/close):

1. Upsert `reading_state`.
2. Update the active history row for this book (the open session: prefer row with `closed_at IS NULL`, else newest by `opened_at`): set `page_id`, `print_page`, `section_title` (sticky TOC title for current `page_id`, or null if TOC empty), and on dispose set `closed_at=now`.

`section_title` = title of the sticky TOC entry for the current page (SPEC-012 helper), truncated only for storage if needed — display uses as stored.

### Coalescing & pruning

- **Coalesce window:** 30 minutes (constant; unit-testable).
- **Prune on every insert** (not update): delete rows where `opened_at` is older than **90 days**, then if count still &gt; **500**, delete oldest by `opened_at` until ≤ 500.
- **Clear all:** `DELETE FROM reading_history` (user-confirmed). Does **not** clear `reading_state` or bookmarks.
- **Remove one:** delete by `id`. Does not affect `reading_state`.

### Resume navigation

- If book not installed → UI shows unavailable state; do not open reader until installed.
- If installed: prefer jump by `print_page` when non-null (existing `pageByPrintNumber`); else jump by `page_id`. If target missing after reinstall → snackbar `pageNotFound` (existing string); open book at last `reading_state` or first page.

## 3. Bookmarks semantics

- Toggle for **current** `(book_id, part, page_id)`: insert or delete.
- Snackbar on add: localized “bookmark added” with print page (or —) + **Undo** action that deletes the just-created row.
- Snackbar on remove: localized “bookmark removed” (Undo optional: re-insert same fields).
- Rename: update `label` (empty string → store NULL).
- Distinct from SPEC-010: no offsets, no highlight colors.

## 4. UX

Visual language: DESIGN-001 / DESIGN-002 §2–3. RTL-first.

### Library

- Header (outside the green continue-reading card): text button **سجل القراءة** (`historyTitle`) that pushes History.
- Continue-reading hero eyebrow: **متابعة القراءة** only; card body opens the latest book at its position.
- Hero data = newest `reading_history` row (`ORDER BY opened_at DESC LIMIT 1`), joined to catalog for title/spine; if none, keep current empty/hero-hidden behavior.

### History screen (pushed)

- AppBar: title `historyTitle` (Amiri) + destructive text `historyClear` → confirm `historyClearConfirm`.
- Day groups with `SectionLabel`: `today` · `yesterday` · `thisWeek` · `older` (local calendar; group by `opened_at`).
- Row: spine + title + line `section_title · ج… · ص…` + relative time caption; tap resumes; overflow: `removeFromHistory` · book card (existing بطاقة flow).
- Uninstalled: dashed unavailable + `notInstalled` + download affordance (SPEC-008 enqueue).
- Empty: rosette + `historyEmpty`.
- Width ≥800: content max 760 centered.

### Reader

- Top bar (RTL): back · title · search · **bookmark toggle** · TOC · ⋯.
- Bookmark glyph outline; filled `goldSoft` when current page bookmarked.
- Side pane / TOC sheet tabs: **الفهرس | العلامات | الملاحظات** with count badges on bookmarks and notes (SPEC-012 notes tab retained).
- Bookmark list row: gold glyph + `label ?? section_title ?? "ص X"` + trailing print page; tap jumps; long-press → rename / delete.
- Empty bookmarks: `bookmarksEmpty`.

## 5. ARB keys (ar / en / fr)

Add at least: `historyTitle`, `historyClear`, `historyClearConfirm`, `historyEmpty`, `today`, `yesterday`, `thisWeek`, `older`, `removeFromHistory`, `notInstalled` (if not already), `bookmarks`, `bookmarkAdded`, `bookmarkRemoved`, `renameBookmark`, `bookmarksEmpty`, `historyLink` (eyebrow “السجل” / “History”).

Reuse existing keys where they already match (`openBook`, `bookCard`, `pageNotFound`, `undo` if present — otherwise add `undo`).

## 6. Implementation notes

- Files (indicative): `state_database.dart` migration + APIs; `history_page.dart`; Library hero update; `reader_page.dart` toggle + 3-tab pane; optional `lib/ui/history_row.dart`, `bookmark_row.dart`.
- Providers: day-grouped history list; `bookmarksForBook(bookId)`; `isPageBookmarked(bookId, part, pageId)`.
- Unit tests **before** UI: coalesce window; prune 90d and 500-cap; clear-all; bookmark UNIQUE toggle; resume prefers `print_page`.
- `CHANGELOG.md` Unreleased entry when implementing.

## Acceptance criteria

- [x] `user_version` ≥ 6 creates `reading_history` and `bookmarks` on fresh and upgraded state DBs.
- [x] Opening/reading a book writes/updates history; re-open within 30 min coalesces; prune enforces 90 days and 500 rows (unit tests).
- [x] Clear history removes all history rows only; `reading_state` and bookmarks untouched.
- [x] Library hero reflects latest history; “السجل” opens History; empty state when no rows.
- [x] History tap resumes installed book at `print_page` or `page_id`; missing page → existing not-found snackbar.
- [x] Bookmark toggle add/remove with UNIQUE constraint; gold filled state; Undo on add works.
- [x] TOC pane / sheet shows three tabs; bookmark jump + rename + delete work.
- [x] No writes into book bundles; print pages never invented.
- [x] `flutter analyze` clean; unit tests green; no new dependencies.

## Out of scope

- DESIGN-002 F3–F7 (storage manager, app language/About, library-wide FTS, author pages, annotation export).
- Cloud sync; reading streaks/stats; changing `reading_state` schema.
- Author bio fields; `share_plus` or any new package.

## Dependencies

Existing allowlist only (`sqlite3`, Flutter Material, Riverpod, current l10n). DESIGN-001 shared widgets.
