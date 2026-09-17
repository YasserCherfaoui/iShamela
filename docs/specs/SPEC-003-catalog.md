# SPEC-003 — Library Catalog & Bundle Distribution

**Status:** Ready for implementation · **Depends on:** SPEC-002 · **Deliverables:** `data/src/ishamela_data/build_catalog.py` (+ CLI `ishamela-catalog`), distribution layout on Hugging Face

## Purpose

The app needs one small, downloadable file answering: *what books exist, how are they organized, and where do I download each bundle?* This spec defines how the catalog is built from SPEC-002's per-book JSON sidecars and how all artifacts are hosted.

## Distribution decision

Artifacts are published to a **Hugging Face dataset repo** owned by the project (e.g. `ishamela/bundles`). Rationale: free hosting for large files, CDN-backed `resolve/` URLs, versioned by git revision, consistent with the project's data provenance. GitHub Releases is the fallback if HF policy blocks it (record as ADR if switched).

Repo layout:

```
ishamela/bundles (HF dataset)
├── catalog/
│   ├── catalog.json            # tiny version manifest (see below)
│   └── catalog.sqlite.zst      # full catalog DB
└── books/
    ├── book_1.isb
    ├── book_2.isb
    └── ...
```

## `catalog.json` (version manifest, fetched at every app start)

```json
{
  "catalog_version": 3,
  "generated_at": "2026-09-17T00:00:00Z",
  "schema_version": 1,
  "norm_version": "1.0.0",
  "catalog_sqlite_zst": {"path": "catalog/catalog.sqlite.zst", "bytes": 0, "sha256": "..."},
  "books_base_url": "https://huggingface.co/datasets/ishamela/bundles/resolve/main/books/",
  "book_count": 8589,
  "min_app_version": "0.1.0"
}
```

App logic: if local `catalog_version` < remote, download and swap `catalog.sqlite`. The manifest MUST stay < 2 KB; it is the only unconditional network call in the app (SPEC-004).

## `catalog.sqlite` schema (`CATALOG_SCHEMA_VERSION = 1`)

```sql
CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
-- catalog_version, schema_version, norm_version, generated_at, source_revision

CREATE TABLE categories (
  id INTEGER PRIMARY KEY, name TEXT NOT NULL, position INTEGER NOT NULL
);

CREATE TABLE authors (
  id INTEGER PRIMARY KEY, name TEXT NOT NULL, death_year_hijri INTEGER
);

CREATE TABLE books (
  book_id INTEGER PRIMARY KEY,
  title TEXT NOT NULL,
  author_id INTEGER REFERENCES authors(id),
  category_id INTEGER NOT NULL REFERENCES categories(id),
  page_count INTEGER NOT NULL,
  volume_count INTEGER,
  isb_bytes INTEGER NOT NULL,
  sqlite_bytes INTEGER NOT NULL,      -- decompressed size, for storage UI
  sha256 TEXT NOT NULL,               -- of the .isb file
  filename TEXT NOT NULL              -- e.g. book_43.isb
);

CREATE VIRTUAL TABLE books_fts USING fts5(
  title_norm, author_norm, content='', tokenize='unicode61 remove_diacritics 0'
);
-- rowid == books.book_id; *_norm produced by SPEC-001 normalize()
```

Upstream author/category fields come from `_meta/*.parquet`; exact columns confirmed by SPEC-002's schema verification gate — extend `docs/DATA_SOURCES.md` if author metadata lives elsewhere. If `death_year_hijri` is unavailable upstream, keep the column NULL; do not scrape other sources.

## CLI contract

```
ishamela-catalog --sidecars ./dist --out ./dist/catalog [--base-url <url>]
```

- Consumes every `book_*.json` sidecar in `--sidecars`; refuses to run (non-zero exit, listing offenders) if any sidecar has a `norm_version`/`schema_version` differing from the rest — a catalog release is homogeneous.
- Deterministic output (same rule as SPEC-002).
- `catalog_version` is passed by CI (monotonic integer), not invented by the script: `--catalog-version N` required.

## Acceptance criteria

- [x] Catalog built from ≥ 3 sidecars validates: FK integrity (`PRAGMA foreign_key_check` clean), every `books.filename` matches its sidecar, `books_fts` rowcount == books rowcount.
- [x] Catalog title search for a book title typed WITH diacritics returns the book (query normalized per SPEC-001).
- [x] Mixed-version sidecars are rejected with a clear error.
- [x] `catalog.json` validates against a JSON Schema committed at `data/schemas/catalog.schema.json` (deliverable of this spec).
- [ ] Full-corpus catalog (8,589 books) < 15 MB compressed (manual/CI check after full sidecar build).
- [x] Determinism: identical inputs ⇒ identical sha256.

## Out of scope

- Delta/incremental catalog updates (full swap is fine at this size).
- PDF-library datasets (their catalog is a future spec).
- CI publishing workflow and live app selection UX — see [`SPEC-007-live-catalog.md`](SPEC-007-live-catalog.md); this spec ends at files on disk.