# SPEC-013 — Downloads Queue Tabs & Library Browse

**Status:** Implemented · **Depends on:** SPEC-004, SPEC-007, SPEC-008, SPEC-009 · **Deliverable:** Downloads tabs + bulk actions; Library nested/tabs browse + search + hover card

## Purpose

Make Downloads manageable (status tabs, multi-select bulk actions, no progress on finished/failed rows) and make Library navigable (category / author / all-books views, search, bulk delete, hover preview of بطاقة الكتاب).

## A. Downloads page

### Tabs

| Tab id | Label (AR) | Statuses included |
|---|---|---|
| `active` | جاري التنزيل | `queued`, `downloading`, `verifying`, `installing`, `paused` |
| `failed` | فشل | `error` |
| `completed` | مكتمل | `done` |

Empty tab → localized empty hint.

### Progress

- Show `LinearProgressIndicator` **only** for `queued` / `downloading` / `verifying` / `installing` / `paused` when `bytesTotal` is known and &gt; 0.
- **Never** show a progress bar on `failed` or `completed` rows.

### Multi-select & bulk actions

AppBar enters select mode (checklist) or long-press a row. Bulk actions apply to the current tab’s selection:

| Action | Active | Failed | Completed |
|---|---|---|---|
| Select all / Deselect all | ✓ | ✓ | ✓ |
| Pause | ✓ (in-flight / queued) | — | — |
| Resume | ✓ (paused) | — | — |
| Cancel / remove from queue | ✓ | ✓ | — |
| Redownload | — | ✓ | ✓ |
| Delete (uninstall) | — | — | ✓ |

**Redownload:** remove installed book + queue row if present, then `enqueue` a fresh install (SPEC-008).  
**Delete (completed):** `deleteInstalled` (file + `installed_books` + downloads row).  
**Cancel:** existing `cancel` (queue + partials; does not remove an already-installed file unless combined with delete).

Per-row trailing actions remain for the non-select mode (same semantics).

## B. Library page

### Browse modes (tabs)

| Mode | Content |
|---|---|
| `categories` | List of categories that have ≥ 1 **installed** book → tap → books in that category (installed only) |
| `authors` | Authors with ≥ 1 installed book → tap → that author’s installed books |
| `books` | Flat list of all installed books |

Nested lists use a back affordance to return to the parent list within the same tab.

### Search

- Search field filters the **current** list (category names / author names / book titles+authors) with case-folded substring match after SPEC-001 `normalize` on both query and title/author (display list filter only — not FTS).
- Clearing search restores the full current list.

### Bulk actions

- Select mode on any books list: **Select all / Deselect all / Delete** (uninstall selected via `deleteInstalled`).
- Confirm dialog before bulk delete.

### Hover / preview card

- Desktop / pointer devices: hovering a book row shows a floating **بطاقة** preview (title, author, category, page count if known, `betaka_text` / `meta.betaka` excerpt ≤ ~400 chars).
- Touch: long-press opens the same preview in a dialog / bottom sheet.
- Primary tap still opens the reader.

## Acceptance criteria

- [x] Downloads shows three tabs; progress hidden on failed/completed.
- [x] Multi-select bulk pause/resume/cancel/redownload/delete behave per table above.
- [x] Library tabs: categories → books, authors → books, all books; search filters; bulk uninstall.
- [x] Hover/long-press shows book card preview.
- [x] `flutter analyze` clean; widget/unit coverage for tab filtering helpers; CHANGELOG updated.

## Dependencies

Existing Flutter allowlist only.

## Out of scope

- Cloud sync; download while terminated; grid/cover art; editing betaka.
