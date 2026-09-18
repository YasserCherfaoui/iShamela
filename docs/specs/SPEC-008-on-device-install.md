# SPEC-008 — On-Device Install from Shamela4 CDN

**Status:** Implemented · **Depends on:** SPEC-001, SPEC-002 (schema), SPEC-003 (catalog path field), SPEC-004 · **Deliverable:** app on-device installer + catalog `source_pages_path` + bundled catalog asset refresh

## Purpose

Users install a book by fetching its raw `pages.jsonl` from Hugging Face `AuthenticIlm/Shamela4_Full_DB` and building the SPEC-002 SQLite+FTS5 database **on the device**. No pre-built `.isb` CDN is required for download.

```
User taps Download
  → GET …/resolve/<rev>/{source_pages_path}
  → stream pages.jsonl
  → local SPEC-002 sqlite (pages + pages_fts)
  → books/book_<id>.sqlite + installed_books
```

## CDN & pin

| Item | Value |
|---|---|
| Dataset | `AuthenticIlm/Shamela4_Full_DB` |
| Default base | `https://huggingface.co/datasets/AuthenticIlm/Shamela4_Full_DB/resolve/main/` |
| Pinned revision (v1) | `07554bee488a12955dd5231d08487ae7ce767d1e` (same as DATA_SOURCES / SPEC-002 gate) |
| Pages URL | `{base}{source_pages_path}` with base using the pinned revision segment when not `main` |

App compile-time: `CATALOG_BASE_URL` / `SHAMELA4_REVISION` (optional override). Default revision constant in app config.

## Catalog requirement (`CATALOG_SCHEMA_VERSION = 2`)

Extend `books` (SPEC-003):

```sql
ALTER TABLE books ADD COLUMN source_pages_path TEXT;
-- Hub-relative path, e.g. 01__العقيدة/1__slug/pages.jsonl
```

- Filled by `ishamela-catalog --from-meta-only` using the same pages index as SPEC-002 (`list_repo_files` → book_id → path).
- `NULL` / empty ⇒ Download disabled for that row (path unknown).
- Browse fields (`title`, author, category) still come from `_meta` parquets.
- Download-size placeholders (`isb_bytes=0`, zero sha256) remain for rows not pre-bundled; **UI must not gate Download on `isb_bytes`** — installability is `source_pages_path IS NOT NULL`.

Bundled app asset `assets/catalog/catalog.sqlite.zst` must be regenerated with schema 2 + paths.

## Install pipeline (replaces `.isb` GET for this mode)

Statuses (reuse SPEC-004 `downloads` table): `queued` → `downloading` → `installing` → `done` | `error` | `paused`.

1. **queued → downloading:** HTTP GET (Range resume) of `pages.jsonl` into `tmp/book_<id>.pages.jsonl`.
2. **downloading → installing:** Open temp SQLite; create SPEC-002 schema; stream JSONL lines; map `sequence_num`→`id`, `part`, `page_num`→`page_number`, `body` verbatim; `body_norm = normalize(body)` into contentless `pages_fts`; write `meta` keys (same as SPEC-002, `built_by` = app version string); `VACUUM`; atomic rename to `books/book_<id>.sqlite`.
3. **installing → done:** Insert `installed_books`; delete temp jsonl; remove any `.isb` expectation.

Rules: max 2 concurrent; pause/resume/cancel; cancel deletes partials; `body` never transformed.

## Acceptance criteria

- [ ] SPEC-008 written; catalog schema documents `source_pages_path`.
- [ ] Catalog built with `--from-meta-only` includes paths for ≥ sample books (incl. book_id `1`).
- [ ] App: Download book_id `1` (fixture or live) produces `books/book_1.sqlite` with `meta` keys and page count matching fixture/upstream.
- [ ] Diacritic FTS smoke: `pages_fts MATCH normalize(query)` finds a known page on the installed fixture.
- [ ] Cancel mid-download leaves no installed row and no leftover sqlite.
- [ ] Airplane mode after install: Library still opens the book DB read-only.
- [ ] `flutter analyze` clean; unit tests for installer + download service green; CHANGELOG updated.

## Dependencies

Flutter: existing SPEC-004 allowlist only (`dio`, `sqlite3`, `crypto`, …). No new packages without asking.

Python catalog: existing SPEC-002/003 allowlist (`huggingface_hub`, `polars`, …).

## Out of scope

- Publishing `.isb` to HF; on-device zstd `.isb` packaging.
- Corpus-wide multi-book search; PDF libraries; SPEC-005 reader UI (install only).
- Auto-building all 8,589 books in CI.
