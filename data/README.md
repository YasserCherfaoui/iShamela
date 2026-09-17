# ishamela-data

Python pipeline that turns Hugging Face datasets into searchable iShamela book bundles.

## Setup

```bash
cd data
uv sync
```

Requires Python 3.12+.

## Commands

```bash
# unit tests (offline fixtures)
uv run pytest

# HF integration test (downloads ʿAqīdah sample book_id=1)
ISHAMELA_HF=1 uv run pytest -m integration

# build one book bundle
uv run ishamela-build --book-id 1 --out ./dist --hf-cache ./hf --keep-sqlite

# build entire corpus (CI)
uv run ishamela-build --all --out ./dist --hf-cache ./hf

# build catalog from sidecars (SPEC-003)
uv run ishamela-catalog \
  --sidecars ./dist \
  --out ./dist/catalog \
  --catalog-version 1 \
  --generated-at 2026-09-17T00:00:00Z \
  --hf-cache ./hf \
  --keep-sqlite
```

Outputs per book:

- `book_<id>.isb` — zstd (level 19) of the SQLite bundle
- `book_<id>.json` — sidecar metadata for the catalog (SPEC-003)
- `book_<id>.sqlite` — only with `--keep-sqlite`

Catalog outputs (`--out`):

- `catalog.json` — tiny version manifest (&lt; 2 KB)
- `catalog.sqlite.zst` — full catalog DB (categories, authors, books + FTS5)
- `catalog.sqlite` — only with `--keep-sqlite`

`--catalog-version` and `--generated-at` are required so CI controls versioning and builds stay byte-identical. Full-corpus catalog must stay under 15 MB compressed (manual/CI check).

## Modules

| Module | Spec |
|---|---|
| `ishamela_data.normalizer` | SPEC-001 |
| `ishamela_data.build_bundle` / `ishamela-build` | SPEC-002 |
| `ishamela_data.build_catalog` / `ishamela-catalog` | SPEC-003 |

Upstream field mappings: [`docs/DATA_SOURCES.md`](../docs/DATA_SOURCES.md).
JSON Schema for `catalog.json`: [`schemas/catalog.schema.json`](schemas/catalog.schema.json).
