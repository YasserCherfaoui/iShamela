---
name: arabic-text
description: Use when writing or reviewing any code that touches Arabic text in iShamela — normalization, search indexing, FTS5 queries, tokenization, RTL rendering, or the shared test vectors. Provides the exact Unicode ranges, folding table, and FTS5 configuration that are contractual in this repo.
---

# Arabic Text Handling — iShamela Skill

## When this applies
Any task in `data/` touching `body_norm`, any task in the app's search or reader modules, any change near `shared/norm_test_vectors.jsonl`.

## The contract (from SPEC-001 / SPEC-002 — those files win over this summary)

Pipeline order: **NFC → strip → fold → digits → punctuation → whitespace collapse.**

Strip:
- Tashkīl: U+064B..U+065F, U+0670
- Tatweel: U+0640
- Quranic annotation: U+06D6..U+06ED

Fold:
- U+0623, U+0625, U+0622, U+0671 → U+0627 (ا)
- U+0649 → U+064A (ي)
- U+0629 → U+0647 (ه)
- U+0624 → U+0648 (و) · U+0626 → U+064A (ي) · U+0621 (ء) → removed
- U+0660..U+0669, U+06F0..U+06F9 → ASCII digits

FTS5 (fixed): contentless table, `tokenize='unicode61 remove_diacritics 0'`, `pages_fts` rowid == `pages.id`.

## Invariants to enforce in review
1. `pages.body` never modified — display text is sacred.
2. `normalize()` exists exactly twice (Python, Dart); identical behavior proven by the shared vectors; idempotent.
3. Query side always normalizes user input with the same function before `MATCH`.
4. Rule changes ⇒ `NORM_VERSION` bump + spec update + vectors update, one PR.

## Common mistakes to catch
- Using Python `unicodedata` category stripping (kills valid letters) instead of the explicit ranges.
- FTS5 `remove_diacritics 2` (double-processing) or `trigram` tokenizer (index bloat, not in spec).
- Highlighting search hits against `body` using `body_norm` offsets without an offset map (lengths differ after stripping).
- Testing RTL layouts with Latin placeholder text.
- Regenerating test vectors from the implementation under test (circular validation).
