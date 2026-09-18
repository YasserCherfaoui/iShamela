# SPEC-017 — Library-Wide Full-Text Search

**Status:** Draft · **Implements:** DESIGN-002 F5 (§6) · **Depends on:** SPEC-001 (normalization), SPEC-005 (normalize-with-map offsets), SPEC-009 (in-book search semantics), SPEC-014 (reading history for ordering), ADR-001 (per-bundle FTS5)
**Goal:** One query across the full text of every *installed* book, streamed and cancellable, reusing each bundle's existing FTS5 index. Zero new storage; fully offline.

---

## 1. Entry & modes

- **LS-01** In the Library tab, when the search query is non-empty, a scope segmented row appears under the field: **العناوين** (default; today's title/author/category filtering, unchanged) | **النصوص**.
- **LS-02** Switching scope re-runs the query in the new mode and cancels any in-flight text search. Scope resets to العناوين when the field is cleared.
- **LS-03** النصوص requires ≥ 2 characters after SPEC-001 normalization; below that, show hint "أدخل حرفين على الأقل" and do not search.
- **LS-04** Debounce 300 ms; each new keystroke cancels the running search before starting a new one.
- **LS-05** The **exact-phrase chip** (same widget and semantics as in-book search per SPEC-009) is shown in النصوص mode and applies to all books.

## 2. Execution model

- **LS-10** A `LibrarySearchService` iterates installed bundles with **bounded concurrency = 2** workers (config constant; 1 on low-RAM devices if a heuristic flags it). Each worker opens the bundle DB **read-only**, runs the FTS query, emits, and closes before taking the next bundle.
- **LS-11** Book order: most-recently-read first (SPEC-014 `reading_history`), then remaining installed books by title collation. Rationale: first useful results in < 500 ms typical.
- **LS-12** Query construction identical to in-book search: SPEC-001 normalization → FTS5 `MATCH` (phrase-quoted when exact-phrase is on). No prefix operators (`كتاب:` etc.) in this mode — they are catalog-search features (SPEC-009) and are treated as literal text here.
- **LS-13** Per-book hit cap **50** with the book's true total available cheaply (`count(*)` capped at 200, displayed as `٥٠+`/`٢٠٠+`). A tail row **عرض المزيد داخل الكتاب** opens the Reader's in-book search pre-filled with the query and phrase flag.
- **LS-14** Results stream into the UI per book as each completes; a slim linear progress under the field shows `جارٍ البحث في {done} من {total} كتابًا…` and hides on completion/cancel.
- **LS-15** Cancellation: clearing the field, editing the query (via debounce), switching scope, leaving the tab, or backgrounding the app. Cancellation closes worker DB connections promptly.
- **LS-16** A corrupt/unopenable bundle is skipped, logged (debug), counted as done; no user-facing error row. If **all** bundles fail, show the generic error empty state with retry.
- **LS-17** Searching must not degrade a concurrently open Reader: workers use separate read-only connections; if the target bundle is the currently open book, reuse its existing connection pool read-only.

## 3. Results UI

- **LS-20** Result group per book: header = mini spine (32×46) + Amiri title + hit-count chip (`٤٢` / `٥٠+`); groups appear in completion order but **re-sort stably to the LS-11 order** once all complete.
- **LS-21** Hit row: gold page pill `ص {printPage}` (**"—" when null — never invented**, tap still navigates via page index) + one-line snippet.
- **LS-22** Snippets come from FTS5 `snippet()` over the normalized shadow text, then mapped back to display text via the SPEC-005 normalize-with-map so the shown excerpt is **verbatim body text** with the match wrapped in the `highlight` mark. Ellipses at truncation boundaries.
- **LS-23** Tap → Reader at that page with the hit highlighted (existing search-hit rendering path from in-book search); back returns to the results as they were (scroll position preserved while the query is unchanged).
- **LS-24** No hits after completion: rosette empty state "لا نتائج في مكتبتك" + tonal button **ابحث في الفهرس** that jumps to Catalog search pre-filled (title/author scope — the catalog has no full-text index; the button label must not promise text search).
- **LS-25** ≥ 800 dp: results render in the content column with the navigation rail intact (DESIGN-001 §5); groups max-width 760.

## 4. Performance targets

- **LS-30** First group visible < 500 ms after debounce on a mid-tier device when the most-recent book is ≤ 10k pages.
- **LS-31** Scrolling stays 60 fps while streaming (list insertions batched per frame; groups virtualized).
- **LS-32** Peak added memory < 40 MB during a 200-book search (bounded workers + streaming, no result hoarding beyond caps).
- **LS-33** Battery/foreground only: search never continues in background.

## 5. Acceptance criteria

1. Query «النية» over 24 installed books: results stream, ordered per LS-11 after completion; every snippet's visible text matches the page verbatim at the tapped location.
2. Exact-phrase «إنما الأعمال بالنيات» returns only phrase matches; toggling the chip re-runs correctly.
3. Typing fast never yields interleaved results from a stale query (cancellation test).
4. A book with a null print page shows `ص —` and still opens the right page.
5. Corrupt bundle injected → search completes over the rest; no crash, no error UI.
6. Reader open on book A while searching: page turns in A remain instant (LS-17).

## 6. Tests

Unit: query builder (normalization + phrase), ordering (history-first), cap/`٥٠+` labeling, snippet offset mapping (property tests against SPEC-005 fixtures), cancellation token. Widget: scope toggle, streaming inserts, empty/error states. Integration: 3-bundle fixture end-to-end incl. tap-through highlight. Perf: LS-30/31 measured in profile mode on the reference device.

## 7. l10n keys

`searchScopeTitles, searchScopeTexts, minQueryHint, searchingBooksProgress, hitsCapped, moreHitsInBook, libSearchEmpty, tryCatalogSearch, searchFailedRetry`

## 8. Open questions

- OQ-1: persist the last text-search query per session (restore on tab return)? Proposed: yes, in-memory only.
- OQ-2: allow category filter chips over text results (e.g. only كتب السنة)? Deferred; keep V1 flat.