# SPEC-005 — Reader & In-Book Search

**Status:** Ready for implementation · **Depends on:** SPEC-001, SPEC-002, SPEC-004 · **Deliverable:** `app/lib/features/reader/` + `core/search/` extensions

## Purpose

Open an installed bundle, read it page by page with faithful Arabic rendering, and search inside it — including correct highlighting, which is the technically subtle part of this spec.

## Reader requirements

- **Navigation:** page-by-page (RTL swipe: forward = right-to-left), jump to print page number (input field validates against `pages.page_number`), jump by part/volume when `pages.part` is populated, scrubber slider.
- **Display:** `pages.body` rendered verbatim. Footnote separators and ornate parentheses ﴿﴾ appear exactly as stored. Every page shows a header: book title · part · **print page number** (citation-critical; show "—" when NULL, never invent one).
- **Typography:** font size slider (persisted), at least two bundled Arabic text fonts suitable for classical texts (e.g., Amiri, Scheherazade New — both OFL; verify licenses in-repo under `app/assets/fonts/OFL.txt`), line-height control, sepia/light/dark themes.
- **Reading state:** last-read page per book — stored in `state.sqlite` via a migration this spec owns:

```sql
CREATE TABLE reading_state (book_id INTEGER PRIMARY KEY, page_id INTEGER NOT NULL, updated_at INTEGER NOT NULL);
```

- **Bookmarks:** the sketch below was **never shipped**. Page bookmarks (schema, toggle UX, TOC tab) are delivered by [`SPEC-014-reading-history-bookmarks.md`](SPEC-014-reading-history-bookmarks.md), which **supersedes** this sketch (`label` instead of `note`; text notes remain SPEC-010):

```sql
-- SUPERSEDED by SPEC-014 — do not implement this shape
CREATE TABLE bookmarks (id INTEGER PRIMARY KEY AUTOINCREMENT, book_id INTEGER NOT NULL, page_id INTEGER NOT NULL, note TEXT, created_at INTEGER NOT NULL);
```

- **Sharing:** "copy citation" produces `«excerpt…» — <title>, <author>, ج<part>, ص<page_number>` (Arabic template in ARB; excerpt = current selection or first line).

## In-book search

Flow: user query → `normalize(query)` (SPEC-001) → build FTS5 MATCH expression → query `pages_fts` → results list (page ref + snippet with highlighted terms) → tap opens reader at that page with highlights visible.

MATCH construction rules:
- Split normalized query on spaces; quote each token (`"..."`) to prevent FTS5 operator injection from user input (`-`, `*`, `NEAR` typed by users must be treated as literals — strip characters FTS5 would parse before quoting).
- Default operator: implicit AND of tokens. A UI toggle "عبارة كاملة" (exact phrase) wraps the whole normalized query as one quoted phrase.
- Empty-after-normalization query ⇒ inline hint, no query executed.

## The highlighting problem (read carefully — this is where naive implementations fail)

The FTS index is **contentless** (SPEC-002): FTS5's `snippet()`/`highlight()` are unavailable, and match offsets refer to `body_norm`, whose character positions differ from `body` (stripping shortens the text). Displayed highlights must land on the **original** text.

Required solution — offset-mapped normalization in `core/search/normalizer_map.dart`:

```dart
class NormResult {
  final String norm;        // == normalize(original), byte-for-byte (invariant, tested)
  final List<int> map;      // map[i] = index in original of the char that produced norm[i]
}
NormResult normalizeWithMap(String original);
```

Semantics: characters *removed* by normalization simply have no norm index; characters *folded* map 1→1; the whitespace-collapse step maps each produced space to the first whitespace char of the run. Invariant test: `normalizeWithMap(s).norm == normalize(s)` for every vector in `shared/norm_test_vectors.jsonl` — reuse the golden file, do not fork it.

Highlighting algorithm (per result page):
1. `nr = normalizeWithMap(body)`.
2. For each query token, find all occurrences in `nr.norm` **at FTS5 token boundaries** (preceded/followed by space or string edge — substring hits inside longer words are not matches and would disagree with FTS5).
3. Map occurrence `[start, end)` in norm space → `[nr.map[start], nr.map[end-1] + 1)` in original space; render `TextSpan` highlights there.
4. Snippet for the results list: window of ~10 words each side of the first hit, taken from **original** text via the same mapping, ellipsized.

## Performance budgets

- In-book FTS query (large multi-volume book): results listed < 100 ms on mid-range Android (ADR-001 target).
- `normalizeWithMap` on a 3,000-word page: < 10 ms (it runs per rendered result page, not per book).
- Page render at 60 fps while swiping; pages lazily loaded (LRU cache ≤ 20 pages).

## Acceptance criteria

- [ ] Reader opens a real installed book; RTL paging direction correct; jump-to-print-page works; state restored on relaunch.
- [ ] Verbatim rendering test: `pages.body` string equality against what the widget receives (no trimming/cleanup anywhere in the pipeline — assert in a widget test).
- [ ] Search for a phrase typed WITH full diacritics finds pages containing the undiacritized text, and vice-versa.
- [ ] Highlights visually cover the diacritized original words (golden/widget test on a fixture page containing tashkīl, tatweel, and ة/ى variants).
- [ ] User input containing `*`, `-`, `"` and `NEAR` does not crash or change semantics (treated literally).
- [ ] Token-boundary test: searching `علم` does not highlight the substring inside `العلماء` unless FTS5 matched it (align behavior with actual FTS5 results on the fixture).
- [ ] All budgets above measured and recorded in the PR description (device model named).
- [ ] Copy-citation works; citation shows the print page number. (Bookmarks: see SPEC-014.)

## Out of scope

- Multi-book/corpus search (post-v1), root search (ADR-001 §5), PDF reader, highlights-as-annotations (colored persistent highlights), text selection across pages.
- TOC pane, HTML display whitelist, reading modes, بطاقة الكتاب, scoped catalog search — see [`SPEC-009-shamela-reader-ux.md`](SPEC-009-shamela-reader-ux.md).
