# SPEC-019 — Notes & Highlights Export

**Status:** Implemented · **Implements:** DESIGN-002 F7 (§8) · **Depends on:** SPEC-005 (annotation offsets), existing copy-with-reference citation generator, annotations store
**Goal:** Export a book's user annotations (highlights + notes) to Markdown or plain text through the system share sheet. The export is the user's own work plus short verbatim anchors with proper citations — never bulk book content.

---

## 1. Entry points & gating

- **EX-01** Reader ⋯ menu item **تصدير الملاحظات والتظليلات**; same item in the Library book-row overflow.
- **EX-02** The item is **disabled with hint** "لا ملاحظات في هذا الكتاب" when the book has zero annotations (menu item visible but non-tappable — discoverability over hiding).

## 2. Export sheet

- **EX-10** Bottom sheet: book title (Amiri) + author caption · format segmented **Markdown | نص** (default Markdown, persisted last choice) · toggles **التظليلات** / **الملاحظات** (default: on for each kind that exists; a kind with zero items renders its toggle disabled-off) · primary **تصدير**.
- **EX-11** تصدير disabled when both toggles are off.
- **EX-12** Counts shown inline on the toggles: `التظليلات ١٢` / `الملاحظات ٤`.

## 3. Content rules

- **EX-20** Entries sorted by reading order: `(part, page_index, start_offset)`.
- **EX-21** **Anchor excerpts are verbatim display text** resolved through SPEC-005 normalize-with-map offsets, truncated to **≤ 300 characters** on word boundaries with «…» — the licensing/posture cap: annotations + short quotes only, never page dumps.
- **EX-22** Each entry carries the **citation line produced by the existing copy-with-reference generator, byte-identical** to what copy-with-reference yields for the same selection (single source of truth; print page "—" rule inherited — never invented).
- **EX-23** A note attached to a highlight nests under that highlight's entry; a standalone note exports its anchor excerpt the same way.
- **EX-24** Markdown flavor: highlight color as a trailing tag (`#أصفر` …); plain-text format omits colors and uses simple indentation. Body text direction: file content is UTF-8 with no BiDi control chars injected; verbatim text stays untouched.

### Markdown template (normative)

```markdown
# ملاحظات — {title}
{author} · صُدِّر في {yyyy-mm-dd}

## ج {part} · ص {printPage}

> {anchor_excerpt}

— {citation_line}  #أصفر

**ملاحظة:** {note_body}
```

(One `##` heading per distinct page; multiple entries stack beneath it. Plain-text mirrors this without `#`/`>` syntax.)

## 4. Generation & delivery

- **EX-30** Generation is a **pure function** `(annotations, bookMeta, options) → String`, golden-tested; runs off the UI thread for large sets.
- **EX-31** Delivery via the system share sheet (`share_plus`) as a file: `notes-{book_id}-{yyyymmdd}.md|txt`, MIME `text/markdown`/`text/plain`. Desktop platforms without a share sheet → save-file dialog instead (same bytes).
- **EX-32** Success snackbar "تم التصدير"; user cancel of the share sheet → silent (no error).
- **EX-33** Export never mutates annotations; concurrent annotation edits during generation use a snapshot read.

## 5. Acceptance criteria

1. Book with 12 highlights + 4 notes (2 attached): Markdown output matches the golden file exactly, entries in reading order, nested notes correct.
2. Every citation line equals the string copy-with-reference produces for that same annotation (automated cross-check test).
3. A 600-char highlight exports a ≤ 300-char anchor cut on a word boundary ending with «…»; the citation still points to the full location.
4. Both toggles off → تصدير disabled; zero-annotation book → menu item disabled with hint.
5. Null print page renders `ص —` in headings and citations.
6. 1,000-annotation stress book generates < 1 s off-thread with no frame drops; share sheet receives a valid UTF-8 file that renders correctly in a Markdown viewer (RTL paragraphs intact).

## 6. Tests

Unit/golden: template rendering (md + txt), truncation on word boundaries, sorting, nesting, color tags, filename builder. Property: anchor excerpt ⊆ page display text for random offset fixtures. Widget: sheet gating logic. Integration: end-to-end share intent (mocked) on Android/iOS, save dialog on desktop.

## 7. l10n keys

`exportAnnotations, exportNoAnnotationsHint, exportFormatMarkdown, exportFormatText, includeHighlights, includeNotes, export, exportDone, exportedOn, notesFileHeading, noteLabel, highlightColorYellow…Orange`

## 8. Open questions

- OQ-1: an "all books" export from Settings? Deferred — per-book keeps files focused and avoids a long-running batch UI.
- OQ-2: include bookmarks (SPEC-014) as a third toggle? Proposed: yes in V1.1 once SPEC-014 ships broadly; template already extends cleanly with a `## العلامات` section.