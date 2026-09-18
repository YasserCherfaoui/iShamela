# SPEC-018 — Author Pages

**Status:** Draft · **Implements:** DESIGN-002 F6 (§7) · **Depends on:** catalog DB (books↔authors), authors `_meta` (death dates, optional bio), SPEC-013 (uninstall via standard rows), existing BookList select/download flows
**Goal:** Make every author name a destination: a pushed screen with the author's identity, dates, optional bio, and their books with full download affordances. Entirely from the local catalog; offline after catalog install.

---

## 1. Navigation & identity

- **AU-01** Navigation is by **`author_id`**, never by name-string matching. Every author render site becomes tappable and must carry the id: book cards (Catalog, Library, book lists, search results), Reader بطاقة pane/sheet, Downloads completed rows' book cards.
- **AU-02** Catalog → Authors tab rows and author hits in Catalog search now push the Author page (**superseding** the bare `BookListPage` for authors). Categories keep `BookListPage` unchanged.
- **AU-03** A book with multiple authors (if present in catalog) lists each name as its own tap target separated by «و»; unknown/absent author renders untappable muted text.
- **AU-04** Deep-link/back behavior: Author page is a normal pushed route; opening a book from it pushes Reader on top (stack depth ≤ 3 from a tab is acceptable).

## 2. Header

- **AU-10** Tonal circle with person glyph + name (Amiri 22, selectable=false) + dates line.
- **AU-11** **Death-date rendering (data contract):** positive value → `ت {n}هـ` with locale digits; **negative value → CE**: `ت {abs(n)}م`; null/0 → omit the dates line entirely. Never convert between calendars in-app.
- **AU-12** Chips row: `{total} كتابًا` · `مثبّت {installed}` (installed chip hidden when 0). Counts from catalog + install registry; reactive to installs.
- **AU-13** Bio block: shown only when the catalog build ships an authors bio field and it is non-empty. Collapsed to 4 lines with **المزيد** expander; text is verbatim corpus data (no cleaning), Amiri 13.5, muted ink. Absent → the block does not render (no placeholder).

## 3. Book list

- **AU-20** Segmented control **الكل | المثبّتة** (default الكل). المثبّتة filters to installed only; empty installed state: "لا كتب مثبّتة لهذا المؤلف".
- **AU-21** Rows are the standard `BookCard` with identical trailing states and behaviors as a category `BookListPage` (installed chip → Reader; download button; progress ring; not-downloadable dashed state).
- **AU-22** Header actions mirror `BookListPage`: **تنزيل الكل** (only when `allowDownloadAll` conditions hold — same rule as categories) + **تحديد**; select mode, confirm sheet, and bulk download reuse the existing flows verbatim (no forked code path — extract the shared controller if needed).
- **AU-23** Local filter field ("تصفية…") above the list, same shared search-field component; filters the author's books by title.
- **AU-24** Sort: catalog's default book ordering for the author (as `BookListPage` today); no new sort UI in V1.

## 4. Performance & offline

- **AU-30** Data loads with the existing batched catalog queries (one query for books + one for install states); target < 150 ms to first frame for a 100-book author.
- **AU-31** Fully functional offline post catalog-install; bio and counts come from the local catalog DB only.

## 5. Acceptance criteria

1. Tapping «النووي» on any surface opens the same Author page (id-routed) with correct counts.
2. Author with death date `-1999` renders `ت ١٩٩٩م` (ar) / `d. 1999 CE` string via l10n in en/fr.
3. تنزيل الكل from an author page enqueues exactly the downloadable, not-installed subset with the standard confirm sheet showing count + sizes.
4. Installing a book from the page flips its row to مثبّت and increments the header chip without refresh.
5. Author with no bio field → no gap where the bio would be.
6. Airplane mode: page opens and browses normally.

## 6. Tests

Unit: date renderer (positive/negative/null), count queries, downloadable-subset selection. Widget: header variants (bio/no-bio, dates/no-dates), segmented filter, select-mode parity with BookListPage (shared golden). Integration: tap-through from four distinct surfaces resolves to one route with the right id.

## 7. l10n keys

`authorBooksCount, authorInstalledCount, showMore, showLess, allBooks, installedOnly, noInstalledForAuthor, filterHint, diedHijri, diedCE`

## 8. Open questions

- OQ-1: catalog build currently exposes bio? If not, ship the screen without it and add the field in the next catalog build (screen is forward-compatible per AU-13).
- OQ-2: birth dates exist for some authors in `_meta` — show `({b}–{d}هـ)` when both present? Proposed: yes if the field ships; renderer already isolates this.