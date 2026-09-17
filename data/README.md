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
```

Outputs per book:

- `book_<id>.isb` — zstd (level 19) of the SQLite bundle
- `book_<id>.json` — sidecar metadata for the catalog (SPEC-003)
- `book_<id>.sqlite` — only with `--keep-sqlite`

## Modules

| Module | Spec |
|---|---|
| `ishamela_data.normalizer` | SPEC-001 |
| `ishamela_data.build_bundle` / `ishamela-build` | SPEC-002 |

Upstream field mappings: [`docs/DATA_SOURCES.md`](../docs/DATA_SOURCES.md).
