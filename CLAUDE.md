# CLAUDE.md — iShamela

Open-source, cross-platform (Flutter) reading & search app for the Islamic Sciences corpus. Data comes from Hugging Face datasets; this repo ships **code only**, never book content.

## Ground rules (non-negotiable)

1. **Spec-driven:** implement only what a `docs/specs/SPEC-*.md` defines. No spec → stop and say so; don't improvise features, schema fields, or dataset field names.
2. **Never modify displayed text.** Normalization (SPEC-001) applies ONLY to `body_norm` and to search queries. `pages.body` is verbatim source text, always.
3. **Golden files are read-only** (`shared/norm_test_vectors.jsonl` etc.) unless the task explicitly includes a spec update.
4. **ADRs are settled.** Don't re-litigate decisions in `docs/adr/` (e.g., don't propose Meilisearch/Tantivy — ADR-001 chose SQLite FTS5). If an ADR seems wrong, flag it; don't code around it.
5. **No new dependencies** outside each spec's allowed list without asking.
6. **Offline-first:** no feature may require network except downloads themselves.

## Layout

- `app/` — Flutter app (Android, iOS, Windows, macOS; web best-effort)
- `data/` — Python pipeline: HF datasets → `.isb` SQLite bundles (Python 3.12, `uv`)
- `docs/adr/` — decisions · `docs/specs/` — implementation contracts · `docs/AI_WORKFLOW.md` — how we work
- `shared/` — cross-language golden test files

## Commands

```bash
# data pipeline
cd data && uv sync
uv run pytest                    # must be green before any PR
uv run ishamela-build --book-id <id> --out ./dist

# app
cd app && flutter analyze && flutter test
```

## Domain crib sheet

- Corpus: `AuthenticIlm/Shamela4_Full_DB` — 8,589 books, 7.6M pages, JSONL pages + parquet metadata. PDF libraries (ieasybooks-org/*) are a later milestone.
- Arabic search pitfalls: diacritics (تشكيل), alef/hamza variants (أ إ آ ا), ى/ي, ة/ه, tatweel. All handled by SPEC-001's normalizer — never hand-roll regexes elsewhere.
- Page numbers are PRINT-edition numbers and are citation-critical; never renumber.
- RTL: all reader UI is RTL-first; test layouts in Arabic, not lorem ipsum.

## Workflow expectations

- Read the relevant spec + ADR fully, then present a file-by-file plan BEFORE writing code.
- Write the spec's acceptance tests first; make them fail; implement.
- One spec per PR. Update `CHANGELOG.md` (Unreleased).
- When output disagrees with the spec's assumptions about upstream data (see SPEC-002 schema gate), report the discrepancy — do not silently adapt.
