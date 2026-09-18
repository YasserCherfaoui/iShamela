# SPEC-012 — Reader Chrome: Full Citations, Note Badges, Sticky TOC, Footnotes

**Status:** Implemented · **Depends on:** SPEC-002, SPEC-005, SPEC-009, SPEC-010 · **Deliverable:** citation fix + notes index UX + TOC highlight + `pages.footnotes`

## Purpose

Polish reader UX after SPEC-010/011: copy the **entire** selection with reference; show notes as numbered badges with a **Notes** index beside TOC; always highlight the current TOC section; render upstream **footnotes** under the page body.

## 1. Copy with reference — full excerpt

Amends SPEC-010 §UX item 5:

- Excerpt = selected display text, whitespace-collapsed (`\s+` → single space), **trimmed**.
- **Do not** truncate or append `…` for length. Clipboard receives the full selection plus the bibliographic suffix.
- Unit test: a 300+ character excerpt appears in full in `formatCitation` output.

## 2. Notes: badges + Notes tab

### Numbering

- Notes for a book are ordered by `(page_id ASC, start_offset ASC, id ASC)`.
- **Index** = 1-based position in that order (stable for the book).
- Body badge shows that index (Arabic-Indic digits optional later; v1 = Western `1`…`n`).

### In-body badge

- At each note’s display start, show a compact circular badge with the index (not merely underline).
- Badge must not break SPEC-010 body-offset mapping: selection indices that include placeholder spans are remapped back to display/body offsets before highlight/note/citation actions.
- Tap / context menu still edits or deletes the note.

### Side pane tabs

Where TOC is shown (wide pane or drawer):

| Tab | Content |
|---|---|
| **TOC** (الفهرس) | Existing TOC list |
| **Notes** (الملاحظات) | All notes for the open book: `#n` · print page (or —) · note preview; tap → jump to `page_id` and focus that note |

Empty notes → localized empty hint.

## 3. Sticky TOC highlight

- While TOC is non-empty, **exactly one** row is selected at all times.
- Active entry = last TOC row (by list order / `position`) whose `page_id <=` current page’s `pages.id`; if current page is before all TOC targets, select the **first** row; if after all, select the **last**.
- Visual: `ListTile.selected` (or equivalent) always true for that row.

## 4. Footnotes (bundle schema 3)

### Schema

Bump book `meta.schema_version` to **`3`**. Extend `pages`:

```sql
ALTER TABLE pages ADD COLUMN footnotes TEXT;  -- verbatim upstream; NULL if absent
```

- New installs (`BundleInstaller` + Python `build_bundle`) create `pages` with `footnotes` and fill from `pages.jsonl` key `footnotes` (string or null; never write into `body` / FTS).
- `footnotes` is **not** indexed in FTS5.
- Books already installed at schema 2: reader treats missing column / null as no footnotes (user re-downloads to get them). Do not migrate old files in place in v1.

### Display

- Below the page body (same scroll view), if `footnotes` is non-null and non-empty after trim:
  - Divider + label «الحواشي» / Footnotes
  - Verbatim footnotes text (HTML whitelist same as body, or plain `SelectableText` if no tags — prefer same whitelist parser for consistency)
- Do not invent footnote markers or renumber.

## Acceptance criteria

- [x] Copy-with-reference of a long selection pastes the full excerpt (no `…` truncation).
- [x] Notes show numbered badges; Notes tab lists book notes and jumps to the page.
- [x] TOC always has one highlighted row tracking the current page section.
- [x] Fresh on-device install stores and shows `footnotes` when present upstream.
- [x] `pages.body` unchanged; footnotes never merged into `body`.
- [x] Unit tests for citation, sticky TOC helper, footnotes column on install; `flutter analyze` clean.

## Dependencies

Existing Flutter / Python allowlists only. `SCHEMA_VERSION` / `bookSchemaVersion` → `3`.

## Out of scope

- In-place migration of schema-2 book files.
- Footnote deep-links from body markers to حاشية lines.
- Syncing notes to cloud.
