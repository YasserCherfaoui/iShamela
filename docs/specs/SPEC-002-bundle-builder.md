# SPEC-002 — Book Bundle Builder

**Status:** Ready for implementation · **Depends on:** ADR-001, SPEC-001 · **Deliverable:** `data/src/ishamela_data/build_bundle.py` (+ CLI entry `ishamela-build`)

## Purpose

Transform one book from `AuthenticIlm/Shamela4_Full_DB` (Hugging Face) into a self-contained, pre-indexed, compressed SQLite bundle the app downloads and opens read-only.

```
HF: pages.jsonl + _meta/*.parquet  →  build_bundle  →  book_<id>.sqlite  →  zstd  →  book_<id>.isb
```

## ⚠️ Schema verification gate (do this first)

The upstream field names below are **assumed from the dataset card** (`book_id`, `body`, per-book `pages.jsonl`, `_meta/book_metadata.parquet`). Task 0 of this spec: download ONE small book + the metadata parquets, print the actual schemas, and record them in `docs/DATA_SOURCES.md`. If reality differs from this spec, update the spec (PR) before implementing. Do not let your AI tool guess field names.

## CLI contract

```
ishamela-build --book-id 43 --out ./dist [--hf-cache ./hf] [--keep-sqlite]
ishamela-build --all --out ./dist            # full corpus (CI use)
```

- Idempotent: same inputs + same `NORM_VERSION` + same `SCHEMA_VERSION` ⇒ byte-identical output (set fixed SQLite `pragma`s, no timestamps inside the DB).
- Exit non-zero with a clear message on: missing book id, empty page set, normalization producing empty index.

## Output SQLite schema (`SCHEMA_VERSION = 1`)

```sql
CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
-- required keys: schema_version, norm_version, book_id, title, author,
--                category_id, category_name, source_dataset, source_revision,
--                page_count, built_by (tool version)

CREATE TABLE pages (
  id           INTEGER PRIMARY KEY,   -- sequential reading order, 1-based
  part         TEXT,                  -- volume/juz' label if present upstream
  page_number  INTEGER,               -- PRINT edition page number (nullable)
  body         TEXT NOT NULL          -- verbatim source text, never modified
);

CREATE VIRTUAL TABLE pages_fts USING fts5(
  body_norm,
  content='',                         -- contentless: we store nothing twice
  tokenize='unicode61 remove_diacritics 0'
);
-- rowid of pages_fts == pages.id ; body_norm = normalize(body) per SPEC-001
```

Notes for the implementer:

- **Contentless FTS5** means snippets are built by the app: it fetches `pages.body` by rowid and highlights by re-running the query-side normalizer with offset mapping — that app-side part is SPEC-004 (reader/search UI), *not* this spec. This spec only guarantees correct rowid alignment.
- `remove_diacritics 0` because diacritics are already gone in `body_norm` (SPEC-001); don't double-process.
- Build inside a temp file, `VACUUM`, then `PRAGMA optimize` before compressing.

## Compression & naming

- Final artifact: `book_<book_id>.isb` = zstd (level 19) of the SQLite file. `.isb` = "iShamela bundle".
- Emit alongside it `book_<book_id>.json`: `{book_id, title, author, category, page_count, isb_bytes, sqlite_bytes, sha256, schema_version, norm_version}` — these JSONs are later merged into the catalog (SPEC-003).

## Acceptance criteria

- [ ] Building book id from the ʿAqīdah category sample completes and the `.isb` opens after decompression with `sqlite3`, all `meta` keys present.
- [ ] `SELECT count(*) FROM pages` equals upstream page count for that book (record both in the test).
- [ ] A search for a known phrase from the book **with full diacritics typed** returns the correct page id via `pages_fts MATCH normalize(query)`.
- [ ] Determinism: two consecutive builds of the same book produce identical sha256.
- [ ] Build of one average book < 30 s on a laptop; memory < 1 GB regardless of book size (stream pages, don't load whole books into RAM).
- [ ] `--keep-sqlite` retains the uncompressed DB for inspection.

## Dependencies (allowed list)

`huggingface_hub`, `polars` (metadata parquets), `zstandard`, stdlib `sqlite3`, `orjson` (optional). Anything else requires PR justification per `docs/AI_WORKFLOW.md`.

## Out of scope

- Catalog generation across books (SPEC-003).
- PDF datasets (separate pipeline, post-MVP).
- Uploading artifacts anywhere (CI concern).
