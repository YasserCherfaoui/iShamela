# SPEC-009 — Shamela-like Catalog Search & Reader UX

**Status:** Implemented · **Depends on:** SPEC-001, SPEC-002 (schema ≥ 2), SPEC-003 (schema ≥ 3), SPEC-005 (in-book search rules), SPEC-008 · **Deliverable:** catalog scoped search + reader chrome (TOC, HTML body display, reading modes, book card, in-book search UI)

## Purpose

Bring the app closer to classic **المكتبة الشاملة** desktop UX for browse and reading, without violating offline-first or verbatim-storage rules.

```
Catalog search  →  scope: all | books | authors | categories
Reader          →  TOC | body (HTML-aware display) | بطاقة الكتاب
                →  reading mode + in-book FTS (SPEC-005 MATCH/highlight rules)
```

## 1. Scoped catalog search

### UI

- Single search field (existing catalog AppBar/body field).
- Scope control (chips or segmented control), RTL:

| Scope id | AR label | Searches |
|---|---|---|
| `all` | الكل | books + authors + categories |
| `books` | كتب | `books_fts` only |
| `authors` | مؤلفون | `authors_fts` only |
| `categories` | أقسام | `categories_fts` only |

- Optional typed prefixes (normalized after strip): `كتاب:`, `مؤلف:`, `قسم:` force that scope for the remainder of the query (overrides chip when present).

### Query construction

1. Parse optional prefix → scope.
2. `q = normalize(remainder)` (SPEC-001). Empty ⇒ show browse tabs (not search results).
3. Build FTS MATCH with **quoted tokens + prefix `*`** (same escaping as SPEC-005 / existing catalog helper) so `AND` / `NEAR` / `*` typed by users cannot break MATCH.

### Result model

Return a discriminated list for the UI:

```
SearchHit = BookHit | AuthorHit | CategoryHit
```

- **BookHit** — existing book row; tap → book list actions (download / open).
- **AuthorHit** — author id/name; tap → books by author.
- **CategoryHit** — category id/name; tap → books by category.

When scope is `all`, section headers group hits (أقسام / مؤلفون / كتب). Cap each section at **50** rows for v1 (document in UI if truncated).

### Catalog schema (bump `CATALOG_SCHEMA_VERSION` → **3**)

```sql
-- existing authors/categories/books …
ALTER TABLE books ADD COLUMN betaka_text TEXT;   -- from book_metadata.betaka_text

CREATE VIRTUAL TABLE authors_fts USING fts5(
  name_norm, content='', tokenize='unicode61 remove_diacritics 0'
);
-- rowid == authors.id; name_norm = normalize(name)

CREATE VIRTUAL TABLE categories_fts USING fts5(
  name_norm, content='', tokenize='unicode61 remove_diacritics 0'
);
-- rowid == categories.id
```

Rebuild bundled `assets/catalog/` after schema bump. App `supportedCatalogSchemaVersions` includes `'3'` (and may drop `'1'`).

## 2. Book bundle: TOC + source page id (`SCHEMA_VERSION` → **2**)

Amend SPEC-002 output (on-device installer SPEC-008 and `ishamela-build` share this schema):

```sql
-- pages: keep existing columns; add:
--   source_page_id INTEGER  -- upstream pages.jsonl `page_id` (unique per book)

CREATE TABLE toc (
  id INTEGER PRIMARY KEY,           -- upstream title_id
  parent_id INTEGER,                -- upstream parent_id (nullable)
  title TEXT NOT NULL,              -- title_text verbatim
  page_id INTEGER NOT NULL,         -- FK → pages.id (resolved via source_page_id)
  position INTEGER NOT NULL         -- reading order (e.g. shamela_title_id)
);
```

### Install / build rules

- Hub TOC path = same directory as `source_pages_path` with filename `toc.jsonl` (do not invent other layouts).
- Stream `toc.jsonl`; map `page_id` (upstream) → `pages.id` via `source_page_id`. Skip TOC rows whose page cannot be resolved (log count; do not fail the install).
- Missing `toc.jsonl` (404) ⇒ empty `toc` table; install still succeeds.
- `meta.betaka` ← catalog `books.betaka_text` when present (verbatim).
- `body` remains **stored** verbatim (including HTML). Never strip tags in the pipeline or installer.
- Duplicate `sequence_num` handling (SPEC-008) unchanged; always persist upstream `page_id` as `source_page_id`.

Upstream TOC keys (normative, from DATA_SOURCES / audit): `title_id`, `book_id`, `page_id`, `parent_id`, `shamela_title_id`, `title_text`.

## 3. HTML-aware body *display* (storage unchanged)

**Problem:** Shamela4 `body` often embeds markup such as  
`<span data-type="title" id=toc-N>…</span>` (see DATA_SOURCES codepoint census).

**Policy:**

| Layer | Rule |
|---|---|
| Storage / FTS | Unchanged raw `body` / `body_norm` |
| On-screen display | Interpret a **whitelist**; do not show raw tags to the user |
| Whitelist | `span` (show text; if `data-type="title"` → heading style), `br` → line break, `b`/`strong` → bold, `i`/`em` → italic |
| Anything else | Strip tags for display only; keep inner text |
| Equality tests | Assert **stored** `pages.body` equals upstream; display widget is allowed to parse for presentation |

No HTML network loads, no scripts. Prefer a small in-app parser; new packages require explicit allowlist update in this spec’s Dependencies section.

## 4. Reading modes

Persist per-app (not per-book) in `state.sqlite`:

```sql
CREATE TABLE IF NOT EXISTS settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
-- key reading_mode ∈ {paged_h, paged_v, continuous_v}
```

| Mode | Behavior |
|---|---|
| `paged_h` (default) | Horizontal `PageView`, RTL forward = right→left (SPEC-005) |
| `paged_v` | Vertical page-by-page `PageView` |
| `continuous_v` | Single vertical scroll of consecutive pages (lazy build) |

UI: reader AppBar / overflow menu to switch mode. Progress indicator uses **LTR isolates** so `current / total` is not visually reversed under RTL.

## 5. Reader chrome (Shamela-inspired)

Three-pane layout on wide screens (≥ 800 dp width); on narrow screens, TOC and بطاقة are drawers / bottom sheets toggled from AppBar:

| Pane | Content |
|---|---|
| **TOC** | Tree or flat list from `toc` ordered by `position`; tap → jump to `page_id` |
| **Body** | Current mode + HTML-aware display + print-page header (SPEC-005) |
| **بطاقة** | `meta.betaka` if set; else title + author + category + page_count from meta/catalog. Label: «بطاقة الكتاب» (book card — upstream `betaka_text`) |

### In-book search UI

Implements SPEC-005 MATCH + `normalizeWithMap` highlighting:

- AppBar action opens search field / route.
- Results list: print page (or —) · snippet with highlights → tap jumps to page and shows highlights.
- Toggle «عبارة كاملة» for phrase MATCH.

## 6. Acceptance criteria

- [ ] Catalog schema 3 ships with `betaka_text`, `authors_fts`, `categories_fts`; bundled asset regenerated.
- [ ] Scoped search: query in scope `authors` returns a known author; `categories` a known category; `books` a known title; `all` returns mixed sections; prefix `مؤلف:` forces authors.
- [ ] On-device install of a book with Hub `toc.jsonl` populates `toc` with ≥ 1 row linked to `pages.id`; book 8041 smoke OK.
- [ ] Reader does **not** show raw `<span…>` for fixture/HTML page; title spans render as emphasized text; stored body still contains the tags.
- [ ] User can switch `paged_h` / `paged_v` / `continuous_v`; preference survives restart.
- [ ] TOC tap navigates to the correct page; بطاقة shows betaka or fallback metadata.
- [ ] In-book search finds a diacritized query on an installed fixture (SPEC-005 rules).
- [ ] `flutter analyze` clean; unit/widget tests cover parser whitelist, scoped search, toc resolve, reading_mode setting.

## Dependencies

Flutter: existing SPEC-004/008 allowlist only, **plus** optionally `flutter_html` **or** a zero-dep whitelist parser (prefer zero-dep). Any new package must be named in the PR.

Python: existing catalog/bundle allowlist; no new packages.

## Out of scope

- Corpus-wide multi-book search; root search (ADR-001 §5).
- PDF libraries; footnotes stream UI (DATA_SOURCES: separate field — later).
- Full CSS / arbitrary HTML; images remote-loaded from body.
- Exact pixel clone of Windows Shamela.
