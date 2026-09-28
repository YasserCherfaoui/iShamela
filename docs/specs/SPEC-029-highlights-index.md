# SPEC-029 — Highlights index in the contents pane

**Status:** Implemented · **Depends on:** SPEC-010, SPEC-012 · **Deliverable:** a highlights tab beside the table of contents

## Purpose

Let the reader find highlighted passages in the open book without scanning every page. Highlights stay user data in `state.sqlite` (SPEC-010). `pages.body` is never modified.

## 1. Where it appears

The wide contents sidebar and the narrow contents sheet share one pane. Tab order:

| Tab | Label (ar / en / fr) |
|---|---|
| TOC | الفهرس |
| Bookmarks | العلامات |
| **Highlights** | **التظليلات** / Highlights / Surlignages |
| Notes | الملاحظات |

The highlights tab sits after bookmarks and before notes. When the book has one or more highlights, the tab label includes the count, the same way bookmarks and notes do. In the 300px sidebar every title stays fully readable: longer labels take a wider share of the bar, and a label that still does not fit scales down instead of being cut off.

## 2. Rows

Source: existing `highlightsForBook`, already ordered by `(page_id ASC, start_offset ASC, id ASC)`. That order is the list order. Do not add columns or tables.

Each row:

- A color dot from the SPEC-010 palette (`yellow`, `green`, `blue`, `pink`, `orange`), using the night variants when the reading atmosphere is night.
- The highlighted words: the `pages.body` slice `[start_offset, end_offset)`, tags stripped the same way the reader keeps inner text (`<br>` becomes a break, other tags drop, inner text stays), then whitespace collapsed (`\s+` → one space) and trimmed. Show at most two lines with an ellipsis. Offsets are clamped to the body length. A missing page shows an empty excerpt.
- Print page as `ص {page}` (or —), the existing page label.
- Tap jumps to that `page_id` with the same jump used by the table of contents.

Empty list: **لا تظليلات بعد** / No highlights yet / Pas encore de surlignages.

The list rebuilds when a highlight is added or removed.

## 3. Acceptance

- [ ] A book with highlights lists them in reading order, each row showing the color, the stripped excerpt, and the print page.
- [ ] Tag stripping and whitespace collapse do not change the stored body string.
- [ ] Offsets past the end of the body are clamped.
- [ ] An empty book shows the empty hint.
- [ ] Tap opens that page.
- [ ] `flutter analyze` is clean. Unit tests cover the excerpt helper.

## Out of scope

- Editing or deleting a highlight from the list (selection on the page still does that).
- A corpus-wide highlights screen.
- New schema fields.
