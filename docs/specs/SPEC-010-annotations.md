# SPEC-010 — Reader Annotations (Highlights, Notes, Copy Citation)

**Status:** Implemented · **Depends on:** SPEC-005, SPEC-009 · **Deliverable:** `state.sqlite` annotation tables + reader selection UX

## Purpose

Let readers mark text like Preview / شاملة: colored highlights, anchored notes, and copy-with-bibliographic reference. Annotations are **user data** in `state.sqlite`, never written into book bundles (`pages.body` stays verbatim).

## Storage (`state.sqlite` migration)

Bump `user_version` as needed:

```sql
CREATE TABLE highlights (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id INTEGER NOT NULL,
  page_id INTEGER NOT NULL,
  start_offset INTEGER NOT NULL,   -- UTF-16 code unit index into pages.body
  end_offset INTEGER NOT NULL,     -- exclusive
  color TEXT NOT NULL,             -- yellow | green | blue | pink | orange
  created_at INTEGER NOT NULL,
  CHECK (start_offset >= 0 AND end_offset > start_offset)
);

CREATE TABLE text_notes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id INTEGER NOT NULL,
  page_id INTEGER NOT NULL,
  start_offset INTEGER NOT NULL,
  end_offset INTEGER NOT NULL,
  note TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  CHECK (length(note) > 0)
);

CREATE INDEX highlights_book_page ON highlights(book_id, page_id);
CREATE INDEX text_notes_book_page ON text_notes(book_id, page_id);
```

Offsets are into the **stored** `pages.body` string (including any HTML markup characters). Display layers that parse HTML for rendering must map selection back to raw body indices (or only offer annotation on the raw/plain selectable view when mapping is ambiguous). v1: annotate against the plain-text selection from a `SelectableText`/`SelectionArea` over the display string built from whitelist parsing **without dropping characters that exist in body** — prefer selecting on verbatim body with visual styling via `TextSpan` so indices match storage.

## Colors

Fixed palette (no arbitrary hex in v1):

| id | AR label | Suggested Material |
|---|---|---|
| `yellow` | أصفر | amber.200 |
| `green` | أخضر | green.200 |
| `blue` | أزرق | lightBlue.200 |
| `pink` | وردي | pink.200 |
| `orange` | برتقالي | orange.200 |

## UX

1. User selects a range in the reader body.
2. Context menu / toolbar: **Highlight** (submenu of colors), **Add note**, **Copy with reference**, **Copy**.
3. Highlight paints background behind the range; overlapping highlights: later `created_at` wins for paint order.
4. Notes: dialog for note text; indicator (icon/underline) on range; tap opens note for edit/delete.
5. **Copy with reference** (clipboard), Arabic template (ARB):

```
«{excerpt}» — {title}، {author}، ج{part}، ص{page}
```

If `part` is null/empty, omit `ج…،`. If print `page_number` is null, use `ص—`. Excerpt = selected text (trimmed, whitespace-collapsed). **Do not truncate** (SPEC-012); older drafts that ellipsized at 280 chars are superseded.

English locale template:

```
"{excerpt}" — {title}, {author}, vol. {part}, p. {page}
```

## Acceptance criteria

- [x] Select text → highlight in each of the five colors; survives app restart.
- [x] Add note on selection; edit/delete; survives restart.
- [x] Copy with reference pastes template with title, author, print page (or —).
- [x] Annotations never modify `pages.body` in the book SQLite file.
- [x] Unit tests for citation formatter and offset clamping; `flutter analyze` clean.

## Out of scope

- Syncing annotations to cloud; sharing annotation files.
- Drawing freeform ink; text selection spanning multiple pages (v1: single page only).
- Full CSS/HTML selection mapping beyond verbatim-body TextSpan rendering.
