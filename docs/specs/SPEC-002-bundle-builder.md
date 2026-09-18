# SPEC-002 — Book Bundle Builder

**Status:** Ready for implementation · **Depends on:** ADR-001, SPEC-001 · **Deliverable:** `data/src/ishamela_data/build_bundle.py` (+ CLI entry `ishamela-build`)

## Purpose

Transform one book from `AuthenticIlm/Shamela4_Full_DB` (Hugging Face) into a self-contained, pre-indexed, compressed SQLite bundle the app downloads and opens read-only.

```
HF: pages.jsonl + _meta/*.parquet  →  build_bundle  →  book_<id>.sqlite  →  zstd  →  book_<id>.isb
```

## Schema verification gate (Task 0 — done)

Verified 2026-09-17 against revision `07554bee488a12955dd5231d08487ae7ce767d1e`. Full schemas live in [`docs/DATA_SOURCES.md`](../DATA_SOURCES.md). Do not invent field names.

**Upstream → bundle mapping (normative):**

| Bundle field | Upstream |
|---|---|
| `pages.id` | `pages.jsonl` → `sequence_num` |
| `pages.part` | `part` |
| `pages.page_number` | `page_num` (print edition; nullable) |
| `pages.body` | `body` (verbatim; never modified) |
| `meta.title` | `book_metadata` → `title_ar` |
| `meta.author` | `main_author_name_ar` |
| `meta.category_id` / `category_name` | `category_id` / `category_name_ar` |

Hub layout has **no** `stage0_raw/` prefix: `{NN}__{category}/{book_id}__{slug}/pages.jsonl` plus `_meta/book_metadata.parquet`.

ʿAqīdah acceptance sample: **book_id `1`** (90 pages). CLI `--book-id 43` remains a generic example (that id is not in ʿAqīdah).

## CLI contract

```
ishamela-build --book-id 43 --out ./dist [--hf-cache ./hf] [--keep-sqlite]
ishamela-build --all --out ./dist            # full corpus (CI use)
```

- Idempotent: same inputs + same `NORM_VERSION` + same `SCHEMA_VERSION` ⇒ byte-identical output (set fixed SQLite `pragma`s, no timestamps inside the DB).
- Exit non-zero with a clear message on: missing book id, empty page set, normalization producing empty index.

## Output SQLite schema (`SCHEMA_VERSION = 2`)

```sql
CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
-- required keys: schema_version, norm_version, book_id, title, author,
--                category_id, category_name, source_dataset, source_revision,
--                page_count, built_by (tool version)
-- optional: betaka (SPEC-009 book card text)

CREATE TABLE pages (
  id              INTEGER PRIMARY KEY,   -- sequential reading order, 1-based
  part            TEXT,                  -- volume/juz' label if present upstream
  page_number     INTEGER,               -- PRINT edition page number (nullable)
  body            TEXT NOT NULL,         -- verbatim source text, never modified
  source_page_id  INTEGER                -- upstream pages.jsonl `page_id` (SPEC-009)
);

CREATE VIRTUAL TABLE pages_fts USING fts5(
  body_norm,
  content='',                         -- contentless: we store nothing twice
  tokenize='unicode61 remove_diacritics 0'
);
-- rowid of pages_fts == pages.id ; body_norm = normalize(body) per SPEC-001

CREATE TABLE toc (
  id INTEGER PRIMARY KEY,             -- upstream title_id
  parent_id INTEGER,
  title TEXT NOT NULL,                -- title_text verbatim
  page_id INTEGER NOT NULL,           -- FK → pages.id (resolved)
  position INTEGER NOT NULL
);
```

Notes for the implementer:

- **Contentless FTS5** means snippets are built by the app: it fetches `pages.body` by rowid and highlights by re-running the query-side normalizer with offset mapping — that app-side part is SPEC-005/009, *not* this spec. This spec only guarantees correct rowid alignment.
- `remove_diacritics 0` because diacritics are already gone in `body_norm` (SPEC-001); don't double-process.
- Build inside a temp file, `VACUUM`, then `PRAGMA optimize` before compressing.
- TOC / `source_page_id` / optional `meta.betaka`: see [`SPEC-009-shamela-reader-ux.md`](SPEC-009-shamela-reader-ux.md). `footnotes` column: see [`SPEC-012-reader-chrome-footnotes.md`](SPEC-012-reader-chrome-footnotes.md). `SCHEMA_VERSION` `1`/`2` bundles remain readable; new builds emit `3`.

## Compression & naming

- Final artifact: `book_<book_id>.isb` = zstd (level 19) of the SQLite file. `.isb` = "iShamela bundle".
- Emit alongside it `book_<book_id>.json`: `{book_id, title, author, category, page_count, isb_bytes, sqlite_bytes, sha256, schema_version, norm_version}` — these JSONs are later merged into the catalog (SPEC-003).

## Acceptance criteria

- [x] Building ʿAqīdah sample book_id `1` completes and the `.isb` opens after decompression with `sqlite3`, all `meta` keys present.
- [x] `SELECT count(*) FROM pages` equals upstream page count for that book (record both in the test).
- [x] A search for a known phrase from the book **with full diacritics typed** returns the correct page id via `pages_fts MATCH normalize(query)`.
- [x] Determinism: two consecutive builds of the same book produce identical sha256.
- [x] Build of one average book < 30 s on a laptop; memory < 1 GB regardless of book size (stream pages, don't load whole books into RAM).
- [x] `--keep-sqlite` retains the uncompressed DB for inspection.

## Dependencies (allowed list)

`huggingface_hub`, `polars` (metadata parquets), `zstandard`, stdlib `sqlite3`, `orjson` (optional). Anything else requires PR justification per `docs/AI_WORKFLOW.md`.

## Out of scope

- Catalog generation across books (SPEC-003).
- PDF datasets (separate pipeline, post-MVP).
- Uploading artifacts anywhere (CI concern).
