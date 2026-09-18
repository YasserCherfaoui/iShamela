# iShamela — Current UI Inventory (for redesign)

**Purpose:** Full descriptive inventory of the **as-shipped Flutter UI** so a design model (e.g. Claude) can propose a better visual system and layout. This is **not** a new product spec — it documents what exists today, what each control does, and what must stay functionally intact.

**App:** iShamela — offline-first Arabic Islamic library reader (Flutter, Material 3).  
**Default locale:** Arabic (`ar`). UI is **RTL-first**. English and French strings also exist.  
**Stack (UI-relevant):** Flutter Material 3, `NavigationBar`, `AppBar` + `TabBar`, Riverpod, no custom design system package.

**Related contracts (do not invent features beyond these):**  
`docs/specs/SPEC-005` … `SPEC-013`, `CLAUDE.md`, ADRs under `docs/adr/`.

---

## 1. Product surfaces (map)

| # | Surface | Route / entry | Role |
|---|---|---|---|
| 0 | **Home shell** | `IshamelaApp` → `HomeShell` | Bottom nav hosts 4 tabs |
| 1 | **Catalog** | Tab 0 | Browse / search entire corpus; download books |
| 2 | **Library** | Tab 1 | Browse **installed** books only |
| 3 | **Downloads** | Tab 2 | Queue: active / failed / completed |
| 4 | **Settings** | Tab 3 | Reader typography & text-role colors |
| 5 | **Book list (pushed)** | From Catalog category/author/search | Books in a category or by author; multi-download |
| 6 | **Reader** | Pushed full-screen from Library / Catalog / Downloads | Read one installed book |

There is **no** splash, onboarding, account, or dark theme toggle today.

---

## 2. Global visual language (today)

### Theme
- `ThemeData` + `ColorScheme.fromSeed`
- Seed: `#1B5E4B` (deep green), `Brightness.light` only
- `useMaterial3: true`
- No custom `TextTheme`, component themes, or brand typography for chrome (only reader body fonts)

### Direction & language
- Almost every screen wraps content in `Directionality(textDirection: TextDirection.rtl)`
- App `locale` fixed to `ar` (user cannot switch language in Settings yet)
- Numeric progress (`current / total`) wrapped in **LTR** isolates so digits are not visually reversed

### Typography (chrome vs reader)
- **Chrome (lists, bars, settings):** platform / Material default
- **Reader body:** user-selectable
  - Amiri (default)
  - Scheherazade New
  - System
- Reader default size ~ configurable 14–40; default line height **1.8**, justified Arabic text

### Default reader role colors (Settings / display)
| Role | Default color | Bold |
|---|---|---|
| Body | `#1A1A1A` | no |
| Titles | `#0D5C3D` | yes |
| Honorifics (صلى الله عليه وسلم…) | `#1B7A4E` | no |
| Quran quotes ﴿…﴾ | `#B8860B` | no |
| Punctuation | (configured via Settings) | — |

### Icons
Material outlined icons throughout (`menu_book_outlined`, `library_books_outlined`, `download_outlined`, `settings_outlined`, etc.). No custom icon set.

### Layout density
Mostly dense **ListTile** / **CheckboxListTile** rows. Little whitespace, few cards, almost no imagery (no book covers). Empty states are centered plain text.

### Platforms
Android, iOS, Windows, macOS; web best-effort. Wide layout breakpoint in Reader: **≥ 800 dp**.

---

## 3. Home shell

**File:** `app/lib/app.dart` → `HomeShell`

### Structure
```
Scaffold
├── body: IndexedStack-like swap of 4 pages (actually just pages[_index]; state may reset on tab switch)
└── bottomNavigationBar: NavigationBar (Material 3)
```

### Destinations (order, RTL-aware)
| Index | Label (EN) | Icon |
|---|---|---|
| 0 | Catalog | `Icons.menu_book_outlined` |
| 1 | Library | `Icons.library_books_outlined` |
| 2 | Downloads | `Icons.download_outlined` |
| 3 | Settings | `Icons.settings_outlined` |

### Behavior notes
- No badges on Downloads (e.g. active count)
- No FAB
- Catalog sync starts once when app builds (`catalogSyncTickProvider`)

### Redesign opportunities
- Brand presence on first launch / Catalog
- Download badge / progress on tab
- Preserve 4 primary destinations and offline-first mental model

---

## 4. Catalog tab

**File:** `app/lib/features/catalog/catalog_page.dart`  
**Search field:** `catalog_search_field.dart` (isolated controller so parent rebuilds do not steal focus)

### Layout (top → bottom)
1. **AppBar** — title “Catalog”; action: Refresh (`Icons.refresh`)
2. Optional **stale banner** — if local catalog older than ~30 days: muted bar + info icon + hint to pull/refresh online
3. **Search field** — outlined `TextField`, search prefix icon, clear suffix when non-empty; hint: “Search titles and authors”
4. When query non-empty: **horizontal ChoiceChips** for scope: All | Books | Authors | Categories
5. **Main body**
   - Empty query → **browse TabBar**: Categories | Authors
   - Non-empty → **scoped search results** sections
6. **Footer** (small centered text): `{bookCount} books · installed {installedSize}`

### Browse: Categories / Authors
- Material `TabBar` + `TabBarView`
- Each row: `ListTile` with name only
- Tap → push **BookListPage** (title = category/author name)

### Search results
Sectioned `ListView`:
- Categories (folder icon) → open book list
- Authors (person icon) → open book list
- Books → embedded `BookListView`
- Empty → “No books here”

### Empty catalog (no DB)
Centered message + FilledButton “Refresh catalog” (+ spinner while syncing)

### Functional constraints
- Search uses SPEC-001 normalize + FTS; optional prefixes `كتاب:` / `مؤلف:` / `قسم:` (SPEC-009)
- Offline after first catalog install must still browse

---

## 5. Book list page (pushed from Catalog)

**Widget:** `BookListPage` in `catalog_page.dart`

### AppBar
- Title: category or author name
- **Normal mode:** Select (checklist), optional Download all (if `allowDownloadAll`)
- **Select mode:** Select all, Deselect all, Download selected, Cancel

### Body
1. Filter search field (same `CatalogSearchField`)
2. `BookListView` of books

### Book row (`BookListView`)
| Element | Content |
|---|---|
| Title | Book title |
| Subtitle | Author · page count · download size · category (as available) |
| Trailing (idle) | “Installed” **Chip** if installed; else Download `IconButton` if installable; else nothing |
| Tap | If installed → open **Reader**; else no-op |
| Long-press | Enter select mode (if downloadable & not installed) |
| Select mode | CheckboxListTile; installed / non-installable disabled |

### Confirm download sheet
Modal bottom sheet: title “Download books?”, body with count + download size + approx install size; Cancel / Confirm.

### Redesign notes
- No cover art; text-only rows feel sparse at ~8000 books
- Select mode is icon-heavy in AppBar
- Distinguish “not downloadable” (missing `source_pages_path`) more clearly

---

## 6. Library tab

**File:** `app/lib/features/library/library_page.dart`  
**Shows only installed books.** Lazy: loads data for active tab only.

### Layout
1. **AppBar** — “Library”
   - Tabs: **Categories | Authors | All books**
   - Actions: Select / bulk delete / select-all / deselect / cancel (when showing a book list)
2. **Search field** — debounced 200ms; filters current list (categories, authors, or books)
3. Optional **Back** `ListTile` when drilled into a category or author
4. **Active tab content only** (not all three built at once)

### Categories tab
- List of categories that have ≥1 installed book
- Trailing: count of installed books in that category
- Tap → drill into book list for that category

### Authors tab
- Same pattern for authors

### All books tab
- Flat list of all installed books

### Book row (Library)
| Mode | UI |
|---|---|
| Normal | Title; subtitle author · category; trailing Delete; tap → Reader; long-press → book card dialog; mouse hover → floating overlay card |
| Select | CheckboxListTile |

### Book card (hover overlay / long-press dialog)
Shows: title, author, category, page count, truncated `betaka` (بطاقة) text ≤ ~400 chars. Dialog has Cancel + Open.

### Empty
“No books here”

### Functional constraints
- Delete uninstalls from device (SPEC-013)
- Bulk delete confirms via dialog
- Must stay fast with many installed titles (batched catalog queries)

---

## 7. Downloads tab

**File:** `app/lib/features/downloads/downloads_page.dart`  
**Tabs helper:** `download_tabs.dart`

### AppBar + TabBar
| Tab | Statuses |
|---|---|
| Downloading (active) | queued, downloading, verifying, installing, paused |
| Failed | error |
| Completed | done |

Actions: Select mode → select all / deselect / tab-specific bulk / cancel select.

### Row UI
- Title: book title (from catalog) or `book_{id}`
- Subtitle: localized status string
- **Progress bar only** on active statuses when `bytesTotal > 0` — **never** on failed/completed
- Failed: error message in error color
- Trailing action cluster (`Wrap` of IconButtons) depends on status:
  - Active: Pause / Cancel
  - Paused: Resume / Cancel
  - Failed: Redownload / Cancel
  - Done: Redownload / Open / Delete
- Tap completed → open Reader
- Long-press → enter select mode

### Bulk by tab
| Action | Active | Failed | Completed |
|---|---|---|---|
| Pause / Resume / Cancel | ✓ | cancel only | — |
| Redownload | — | ✓ | ✓ |
| Delete (uninstall) | — | — | ✓ |

### Empty
“Nothing here”

### Pain points for redesign
- Trailing `Wrap` of many icon buttons feels cramped
- No clear visual hierarchy between active progress vs completed
- No estimated time / speed

---

## 8. Settings tab

**File:** `app/lib/features/settings/settings_page.dart`

### AppBar
Title “Settings”; action TextButton “Reset” (resets reader text styles)

### Body (`ListView`)
1. Section **Reader font** — `DropdownButtonFormField`: Amiri / Scheherazade New / System
2. **Font size** — `ListTile` + Slider 14–40
3. Divider
4. Section **Text appearance** — one row per `TextRole`:
   - Title: role label
   - Subtitle: live preview of label in that role’s color/weight/font
   - Trailing: Bold `FilterChip` + circular color swatch
5. Color picker dialog: preset color grid + hex field + OK

### Not in Settings today
- App language
- Theme light/dark/sepia (sepia mentioned historically in SPEC-005; not in Settings UI)
- Download concurrency
- Storage / clear cache
- About / licenses / version

---

## 9. Reader (full-screen)

**File:** `app/lib/features/reader/reader_page.dart`  
**Body / annotations:** `annotated_body.dart`, `body_html.dart`, `text_roles.dart`  
**Opened via:** `ReaderPage.open(...)` push route

### AppBar
- Title: book title (ellipsis)
- Actions:
  1. Search in book (toggles search strip)
  2. TOC (wide: toggle side pane; narrow: bottom sheet)
  3. Book card / بطاقة (wide: toggle side pane; narrow: bottom sheet)
  4. Overflow menu — reading mode:
     - Pages · horizontal (default) — RTL PageView, reverse so forward is RTL
     - Pages · vertical
     - Continuous scroll

### When search open
- Strip under AppBar: search field + “Exact phrase” FilterChip + search IconButton
- Results list (~140px): rows “ص {printPage}” + snippet (around match); tap jumps to page

### Main content (Row when wide ≥ 800)
| Pane | Width | Content |
|---|---|---|
| TOC / Notes | 280 | TabBar: Contents \| Notes; sticky TOC highlight for current section; notes list with badge index + page label |
| Body | flex | See page content |
| بطاقة الكتاب | 280 | Title, author, category, page count, betaka text or empty |

Narrow: side panes as modal sheets.

### Page content (body pane)
1. Header line (centered label): `title · part · printPage` (print page “—” if null — never invent)
2. Divider
3. Scrollable body:
   - `AnnotatedBody` (selectable rich text with roles, highlights, note badges) **or** search-hit highlighted body
   - If footnotes present: section “Footnotes” + smaller styled body
4. **Bottom chrome** (always when book loaded):
   - Slim scrubber slider (page index)
   - Row: **Previous** (right in RTL, chevron_right) | page label `ص…` / `ج… · ص…` | compact jump field | Go | `current/total` LTR | **Next** (left, chevron_left)
   - Nav buttons: filled-tonal rounded IconButtons at **opposite ends** so arrows face outward

### Annotations (selection context menu)
On text selection:
- Highlight colors: Yellow, Green, Blue, Pink, Orange
- Add note (dialog multiline)
- Copy with bibliographic reference (citation format; snackbar “Citation copied”)
- Note badges: superscript-style numbered markers in body; list in Notes tab

### Reading state
- Restores last page per book
- Persist on page change

### Functional constraints (non-negotiable for redesign)
- `pages.body` is **verbatim** for storage; display may whitelist HTML (`span` titles, `br`, bold/italic) — never “clean” stored text
- Print page numbers are citation-critical
- Offline after install
- Highlight offsets use normalize-with-map (SPEC-005)

### Current UX pain (honest)
- Bottom bar still busy on small phones (label + field + go + progress + arrows)
- Search results strip eats vertical space
- Three AppBar actions + menu compete for attention
- Continuous mode + bottom scrubber interaction is basic
- No sepia/night reading theme in chrome

---

## 10. Shared interaction patterns

| Pattern | Where |
|---|---|
| AppBar select mode (checklist → select all / deselect / action / close) | Catalog book list, Library books, Downloads |
| Long-press to enter multi-select | Catalog books, Downloads |
| Confirm destructive / expensive via dialog or bottom sheet | Delete, bulk download |
| SnackBar | Errors, page not found, citation copied, nothing to download |
| Loading | Centered `CircularProgressIndicator` |
| Empty | Centered short string |
| RTL wrapping | Every feature page |

---

## 11. Localization inventory (user-visible EN keys)

Use as checklist that redesign copy must cover (AR is primary UI):

**Shell:** appTitle, tabCatalog, tabLibrary, tabDownloads, tabSettings  

**Catalog:** searchHint, categories, authors, books, refresh, offlineEmpty, catalogFooter, catalogStaleHint, download, downloadSelected, downloadAll, confirmDownloadTitle, confirmDownloadBody, confirm, cancel, installed, pagesCount, openBook, select, selectAll, deselectAll, noBooks  

**Downloads:** downloadsActive, downloadsFailed, downloadsCompleted, downloadsEmpty, pause, resume, cancel, delete, redownload, confirmBulkDelete, statusQueued…statusPaused  

**Library:** libraryAllBooks, back, bookCard, searchHint, delete, …  

**Reader:** jumpToPrintPage, go, previousPage, nextPage, pageNotFound, readerProgress, toc, tocEmpty, bookCard, readingMode, modePagedH/V, modeContinuousV, searchInBook, exactPhrase, footnotes, notesTab, notesEmpty, notePageLabel, highlight + color*, addNote, copyWithReference, copiedCitation  

**Settings:** textAppearance, resetTextStyles, bold, pickColor, colorHex, role*, readerFont, font*, fontSize  

---

## 12. What redesign must preserve (functional)

1. Four primary tabs + pushed book list + full-screen reader  
2. RTL-first Arabic reading experience  
3. Catalog browse (categories/authors) + scoped search + refresh  
4. Install / queue / pause / resume / cancel / redownload / uninstall  
5. Library browse by category / author / all + search + bulk delete + book card preview  
6. Reader: paging modes, print-page jump, scrubber, TOC, notes index, بطاقة, in-book search with exact phrase, footnotes, annotations  
7. Settings for font, size, per-role color/bold  
8. Offline after catalog + books installed  
9. No requirement for book cover images (data may not have them)  
10. Citation-critical print page display  

---

## 13. Known UI weaknesses to improve

1. **Generic Material seed theme** — little brand identity beyond green seed  
2. **List-heavy, card-less** — long Arabic titles wrap awkwardly; weak scanning hierarchy  
3. **Icon-only AppBar actions** — discoverability of select / download all / TOC  
4. **Downloads trailing button clusters** — cluttered  
5. **Reader chrome density** — AppBar + search + hits + bottom bar compete with text  
6. **No dark / sepia reading theme**  
7. **No empty-state illustration / guidance** for first-run Library  
8. **Inconsistent search UX** — Catalog isolated field vs Library plain TextField vs Reader strip  
9. **Wide vs narrow** only thoughtfully done in Reader; Catalog/Library ignore tablets  
10. **Hover book card** desktop-only; mobile relies on long-press dialog  

---

## 14. Suggested brief for the design model

Please produce:

1. **Visual direction** — colors, type, elevation, spacing tokens suitable for a classical Arabic library (avoid generic purple AI aesthetics; respect green heritage seed if evolved).  
2. **Component inventory** — redesigned: bottom nav, list row (book / category / download), search field, chips, empty states, dialogs/sheets, reader chrome (top + bottom), TOC pane, settings rows.  
3. **Screen-by-screen mock descriptions** or ASCII/wire layouts for: Catalog browse, Catalog search, Book list, Library, Downloads (3 tabs), Settings, Reader (phone + tablet).  
4. **Responsive rules** — phone / tablet / desktop.  
5. **Motion** — subtle, purposeful (tab change, page turn affordance, download progress).  
6. **Explicit non-goals** — no social feed, no cover dependency, no breaking SPEC behaviors above.  
7. **Implementation notes for Flutter** — prefer Material 3 theming extensions / shared widgets over one-off styles; keep `Directionality` RTL.

**Output format preferred:** Markdown design doc with sections matching this inventory’s screen list, plus a token table (color, type, radius, spacing).

---

## 15. Source file index

| Area | Path |
|---|---|
| App + shell | `app/lib/app.dart` |
| Catalog | `app/lib/features/catalog/catalog_page.dart` |
| Catalog search field | `app/lib/features/catalog/catalog_search_field.dart` |
| Library | `app/lib/features/library/library_page.dart` |
| Downloads | `app/lib/features/downloads/downloads_page.dart` |
| Settings | `app/lib/features/settings/settings_page.dart` |
| Reader | `app/lib/features/reader/reader_page.dart` |
| Annotated body | `app/lib/features/reader/annotated_body.dart` |
| Text roles / styles | `app/lib/features/reader/text_roles.dart`, `reader_styles.dart` |
| L10n | `app/lib/l10n/app_*.arb` |
| Specs | `docs/specs/SPEC-005` … `SPEC-013` |

---

*Generated as a redesign handoff document for iShamela. Update this file when major UI surfaces change.*
