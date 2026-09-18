# DESIGN-002 — iShamela Feature Additions: History, Bookmarks & Research Tools

**Status:** Proposed (M-F1 Implemented via SPEC-014) · **Depends on:** DESIGN-001 (Warm Manuscript tokens/components — all visuals below reuse them; no new colors or type styles)
**Scope:** New user-facing capabilities layered onto the redesigned shell: reading history, bookmarks, storage manager, settings completions (language/about), library-wide full-text search, author pages, and notes/highlights export. Everything is local-only and offline-first. Dataset `_meta` superpowers (xrefs, narrators, isnads, quran_verses) are explicitly **out of scope** — reserved for DESIGN-003 after their own SPECs.

**Spec mapping:** M-F1 (F1 + F2) → [`SPEC-014-reading-history-bookmarks.md`](../specs/SPEC-014-reading-history-bookmarks.md). F3–F7 need their own SPECs before implementation. SPEC-005’s sketched `bookmarks` table is **superseded** by SPEC-014 (page marks + optional `label`; text notes remain SPEC-010).

---

## 1. Feature summary & placement

| # | Feature | Entry point | New screen? | Data cost |
|---|---|---|---|---|
| F1 | Reading history | Library hero card → "السجل" | Yes — pushed | 1 local table |
| F2 | Bookmarks | Reader top bar toggle; TOC pane tab | No — new pane tab | 1 local table |
| F3 | Storage manager | Settings → التخزين | Yes — pushed | none (derived) |
| F4 | App language + About | Settings cards | Sheet + pushed About | none |
| F5 | Library-wide search | Library search field, "النصوص" scope | No — results in-tab | none (uses bundle FTS5) |
| F6 | Author pages | Any author name tap; Catalog authors tab | Yes — pushed | none (catalog + authors meta) |
| F7 | Notes & highlights export | Reader ⋯ menu; Library row overflow | Sheet | none |

The 4-tab shell is untouched. No fifth destination.

## 2. F1 — Reading history (سجل القراءة)

### Data
New table in the **app-level** SQLite (never in read-only book bundles):

```
reading_history(
  id INTEGER PK,
  book_id INTEGER NOT NULL,
  part TEXT,            -- as displayed, verbatim
  page_id INTEGER NOT NULL,  -- = pages.id (not print number)
  print_page INTEGER,   -- nullable; NEVER invented
  section_title TEXT,   -- nearest TOC entry at close, nullable
  opened_at INTEGER NOT NULL,
  closed_at INTEGER
)
```

- Written by the **same hook that persists last-page state** (`reading_state`): on reader open, insert a session row; on page change/close, update `page_id/print_page/section_title/closed_at`. `reading_state` remains the restore source of truth.
- **Coalescing:** re-opening the same book within 30 min updates the previous row instead of inserting — history reads as sessions, not page flips.
- **Pruning on insert:** keep max 500 rows or 90 days, whichever smaller.
- Local only, never synced; clearable by the user.

### Screen — pushed from Library
- Header: back + title **سجل القراءة** (Amiri 23) + text button **مسح السجل** in `error` color (confirm dialog: "سيُحذف سجل القراءة نهائيًا").
- Body grouped by day with `SectionLabel` headers: **اليوم · أمس · هذا الأسبوع · أقدم**.
- **History row** = `BookCard` variant: spine + Amiri title + line 2 `section_title · ج X · ص Y` + line 3 relative time in muted caption ("قبل ساعتين"). Trailing: none (whole row taps).
- **Tap → resume at the recorded position**: navigate by `print_page` when non-null, else `page_id` (citation-faithful; matches existing jump semantics incl. "الصفحة غير موجودة" snackbar if a re-downloaded bundle changed).
- **Uninstalled book:** row desaturates (dashed-border treatment from DESIGN-001's unavailable state), subtitle gains **غير مثبّت**, trailing shows the tonal download round-button; after reinstall the row resumes normally.
- Row overflow (⋯): إزالة من السجل · بطاقة الكتاب.
- Empty state: rosette + "لم تقرأ شيئًا بعد — افتح كتابًا من مكتبتك".

### Library tie-in
- Hero card: gold eyebrow row becomes `متابعة القراءة · السجل ←` (السجل is the pushed link; the card body still resumes directly).
- The hero **is** history item #1 — same query, `LIMIT 1`.

## 3. F2 — Bookmarks (العلامات)

### Data
Supersedes the unimplemented SPEC-005 sketch (`page_id` + `note`). Page marks are not text annotations (SPEC-010).

```
bookmarks(
  id INTEGER PK,
  book_id INTEGER NOT NULL,
  part TEXT,
  page_id INTEGER NOT NULL,  -- = pages.id
  print_page INTEGER,
  label TEXT,           -- optional user rename
  created_at INTEGER NOT NULL,
  UNIQUE(book_id, part, page_id)
)
```

### Reader UI
- **Top bar gains a bookmark toggle** → order (RTL): back · title block · search · bookmark · TOC · ⋯. Four 38px icon buttons fit at 390dp (≈190px actions incl. back; title column keeps ~180px with ellipsis).
- Glyph: outline bookmark; **filled gold (`goldSoft`) when the current page is bookmarked**. Tap toggles; snackbar "أُضيفت علامة · ص ١٢" with تراجع action.
- Distinct from highlights/notes: a bookmark marks a *page*, annotations mark *text*.

### TOC pane / sheet
- Tabs become three: **الفهرس | العلامات | الملاحظات ٤** (segmented pills, count badges on the latter two).
- Bookmark row: gold bookmark glyph + `label ?? section_title ?? "ص X"` + trailing print page number (muted, far edge) — mirrors TOC row anatomy. Tap jumps; long-press → sheet: إعادة تسمية (single-line dialog) · حذف.
- Empty: "لا علامات بعد — اضغط رمز العلامة أثناء القراءة".

## 4. F3 — Storage manager (التخزين)

- **Settings card "التخزين"**: two stat lines — `المستخدم: ١٫٢ ج.ب (٢٤ كتابًا)` and `المتاح على الجهاز: ١٨ ج.ب` — plus tonal button **إدارة التخزين**.
- **Pushed screen**: header + total bar (5px, `green700` fill = used share of used+free, caption below); list of installed books **sorted by size desc**. Row = spine + title + `٧ أجزاء · ١١٠ م.ب` + trailing size in 600 weight; overflow (⋯): إلغاء التثبيت (existing SPEC-013 flow + confirm) · بطاقة الكتاب.
- Select mode via تحديد (same pattern as everywhere): bulk uninstall with aggregate size in the confirm dialog ("سيحرر ٣٤٠ م.ب").
- No cache-clearing UI in this pass — catalog DB stays managed by sync.

## 5. F4 — Settings completions

New card **اللغة والتطبيق** below ألوان النص:
- **لغة التطبيق** row — value `العربية` + chevron → bottom sheet radio list: العربية · English · Français (ARBs exist; locale persisted; RTL/LTR flips with locale, reader content always RTL).
- **التخزين** rows live in their own card (F3) above this one.
- **حول التطبيق** row → pushed About: rosette + wordmark, version/build, dataset attribution ("بيانات المكتبة الشاملة — AuthenticIlm/Shamela4_Full_DB")، open-source license link, Flutter licenses page.

Settings card order becomes: سمة القراءة · خط القراءة · ألوان النص · التخزين · اللغة والتطبيق.

## 6. F5 — Library-wide full-text search

The step from *reader* to *research tool*; reuses each installed bundle's own FTS5 index — zero new storage.

- **Entry:** the Library search field. When the query is non-empty a scope segmented row appears: **العناوين** (default, current behavior) | **النصوص**.
- **النصوص mode:**
  - Query runs over installed bundles **sequentially, ordered by most-recently-read** (history table), streaming results as each book completes; slim linear progress under the field with caption `جارٍ البحث في ١٢ من ٢٤ كتابًا…`.
  - Existing SPEC-001 normalization + exact-phrase chip (reused from in-book search) apply; per-book hit cap 50 with "عرض المزيد داخل الكتاب" tail row that opens the reader's in-book search pre-filled.
  - **Result group** = mini book header (small spine 32×46 + Amiri title + hit count chip) + **hit rows**: `ص X` gold pill + one-line snippet with `highlight` mark. Tap → reader at that page with the hit highlighted (existing search-hit rendering path).
  - Cancel = clearing the field or switching scope; searches are cancellable mid-stream.
- Empty result: rosette + "لا نتائج في مكتبتك — جرّب البحث في الفهرس" + tonal button to Catalog search with the same query.

## 7. F6 — Author pages

- **Every author name is tappable** (book cards, search results, reader بطاقة) → pushed author screen.
- **Header:** person tonal circle (or calligraphic initial) + name (Amiri 22) + dates line — hijri as stored; the dataset's negative death dates render as CE per data contract ("ت ١٤٢٠هـ" / "ت 1999م") + chips: `١٢ كتابًا · مثبّت ٣`.
- **Bio:** collapsed 4-line excerpt **only when** the catalog ships an author bio field (today: `authors` has `name` + `death_year_hijri` only — **omit the bio block entirely**; no placeholder). When a future catalog/SPEC adds bio, "المزيد" expands.
- **Body:** segmented **الكل | المثبّتة** + standard `BookCard` list with normal download/installed/progress trailing affordances + the same select/تنزيل الكل header actions as a category list.
- **Catalog authors tab rows now push this screen** (superseding the bare BookListPage for authors; categories keep BookListPage). Same for author hits in Catalog search.

## 8. F7 — Notes & highlights export

- **Entry:** reader ⋯ menu → **تصدير الملاحظات والتظليلات**; Library row overflow gets the same item.
- **Export sheet:** scope fixed to the current book (title shown) · format segmented **Markdown | نص** · toggles include التظليلات / الملاحظات (both on) · primary button **تصدير**.
- **Output structure:** book heading (title, author, edition from بطاقة), then entries in page order: quoted passage (highlight text or note anchor) + the existing bibliographic citation line (كتاب، ج، ص — same generator as copy-with-reference) + note body indented beneath its anchor. Highlight color noted as a tag in Markdown only.
- Delivery via the system share sheet (share/save file); filename `notes-<book_id>.md`. Snackbar on completion. (`share_plus` or equivalent — require explicit allowlist ask in that SPEC.)

## 9. New components (added to the DESIGN-001 inventory)

`HistoryRow` · `BookmarkRow` · `PaneTabs3` (TOC/bookmarks/notes) · `BookmarkToggleButton` · `StorageRow` + `StorageBar` · `ValueRow` (label/value/chevron for Settings) · `RadioSheet` · `ResultGroupHeader` (mini spine) · `HitRow` (page pill + snippet) · `SearchStreamProgress` · `AuthorHeader` · `ExportSheet`. All composed from existing tokens; nothing new in the palette.

## 10. Responsive & motion deltas

- ≥800dp: History and Storage screens center at max 760; author page uses 2-col book grid per DESIGN-001 §5; library-wide search results render in the content column with the rail intact; bookmarks tab appears in the persistent reader side pane.
- Motion: history day-groups fade-in on push (no stagger theatrics); bookmark toggle does a 150ms fill + 1.1× settle; streaming search results insert with 120ms fade; storage bulk-uninstall animates freed size counting up in the snackbar. `disableAnimations` respected.

## 11. Non-goals

No cloud sync or accounts (history/bookmarks are device-local); no cross-book xrefs, narrator popups, isnad tooling, or verse-citation graphs (DESIGN-003 after SPECs); no streaks, badges, or reading stats; no export of book *content* beyond the user's own annotations + short quoted anchors; no changes to bundle format, FTS schema, or download pipeline.

## 12. Flutter implementation notes

- **Tables** `reading_history`, `bookmarks` migrate into the existing app `state.sqlite` via `StateDatabase` + `PRAGMA user_version` (version **v6** — v5 is `installed_books.page_count`); repositories + Riverpod providers (`historyProvider` day-grouped, `bookmarksProvider(bookId)`, `isPageBookmarkedProvider`). No drift/sqflite.
- **History hook:** extend the current `upsertReadingState` path in the reader — one code path, no second timer. Coalescing + pruning live in the repository, unit-tested.
- **Library-wide search:** an isolate-friendly service opening bundle DBs read-only one at a time (bounded to 1–2 concurrent to protect low-end devices), emitting a `Stream<BookSearchResult>`; cancellation token wired to the field.
- **Author screen** reuses the batched catalog queries from Library; bio omitted until a catalog/SPEC ships it.
- **Export:** pure function `(annotations, bookMeta) -> String` per format, golden-tested; share delivery only after dependency allowlist.
- **Locale:** `MaterialApp.locale` from settings store; keep reader `Directionality.rtl` regardless of app locale.
- **New ARB keys (all three locales):** `historyTitle, historyClear, historyClearConfirm, historyEmpty, today, yesterday, thisWeek, older, removeFromHistory, notInstalled, bookmarks, bookmarkAdded, bookmarkRemoved, renameBookmark, bookmarksEmpty, storage, storageUsed, storageAvailable, manageStorage, freeUpSpace, uninstallConfirmSize, appLanguage, aboutApp, version, licenses, datasetAttribution, searchScopeTitles, searchScopeTexts, searchingBooksProgress, moreHitsInBook, libSearchEmpty, tryCatalogSearch, authorBooks, authorInstalled, showMore, exportAnnotations, exportFormatMarkdown, exportFormatText, includeHighlights, includeNotes, export, exportDone`.

## 13. Suggested milestones

| M | Contents | Spec |
|---|---|---|
| M-F1 | History table + hook + screen + hero tie-in; bookmarks table + toggle + pane tab | **SPEC-014** |
| M-F2 | Storage card/screen; language + About | (later SPEC) |
| M-F3 | Library-wide search (streamed) | (later SPEC) |
| M-F4 | Author pages; notes/highlights export | (later SPEC) |
