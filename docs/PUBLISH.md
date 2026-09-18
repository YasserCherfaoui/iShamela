# Publishing catalog & bundles (SPEC-007 / SPEC-008)

Operator runbook for catalog assets and optional `.isb` hosting.

## Source vs what the app downloads (SPEC-008)

```
AuthenticIlm/Shamela4_Full_DB
─────────────────────────────────
_meta/*.parquet  ─ ishamela-catalog ──► catalog.json + catalog.sqlite.zst
                                        (+ source_pages_path per book)
pages.jsonl      ─ app on-device install (SPEC-008) ──► books/book_<id>.sqlite
```

| Role | Dataset | What the app uses |
|---|---|---|
| **Source + pages CDN** | [`AuthenticIlm/Shamela4_Full_DB`](https://huggingface.co/datasets/AuthenticIlm/Shamela4_Full_DB) | `pages.jsonl` via `source_pages_path` at pinned revision; `_meta` is **build-time only** |
| **Catalog asset** | Bundled in the app (`assets/catalog/`) and/or optional HF publish | `catalog.json`, `catalog.sqlite.zst` |
| **Optional `.isb` CDN** | e.g. `yassercherfaoui/ishamela-bundles` | Not required for SPEC-008 install; still useful for offline CI builds / archives |

Default pages base (app):  
`https://huggingface.co/datasets/AuthenticIlm/Shamela4_Full_DB/resolve/<SHAMELA4_REVISION>/`

Local overrides: `--dart-define=CATALOG_BASE_URL=…` · `--dart-define=PAGES_BASE_URL=…` · `--dart-define=SHAMELA4_REVISION=…`

## Optional: publish pre-built `.isb` (SPEC-002 / SPEC-007)

| Item | Value |
|---|---|
| Dataset | [`yassercherfaoui/ishamela-bundles`](https://huggingface.co/datasets/yassercherfaoui/ishamela-bundles) |
| Layout | `catalog/catalog.json`, `catalog/catalog.sqlite.zst`, `books/book_<id>.isb` |

## Build → publish (optional CDN)

```bash
cd data
uv sync

# 1) Build per-book bundles (repeat / script over book ids)
uv run ishamela-build --book-id <id> --out ./dist

# 2) Build catalog from sidecars (catalog_version is CI-owned, monotonic)
uv run ishamela-catalog \
  --sidecars ./dist \
  --out ./dist/catalog \
  --catalog-version N \
  --generated-at 2026-09-17T00:00:00Z

# 3) Dry-run (no HF writes) — validates schema + sha256 of every .isb
uv run ishamela-publish \
  --catalog-dir ./dist/catalog \
  --books-dir ./dist \
  --dry-run

# 4) Upload (needs HF_TOKEN with write access to yassercherfaoui/ishamela-bundles)
export HF_TOKEN=hf_...
uv run ishamela-publish \
  --catalog-dir ./dist/catalog \
  --books-dir ./dist \
  --repo yassercherfaoui/ishamela-bundles \
  --revision main \
  --enforce-size-gate   # production: catalog.sqlite.zst must be < 15 MB
```

GitHub Actions: [`.github/workflows/publish-bundles.yml`](../.github/workflows/publish-bundles.yml)
(`workflow_dispatch`). Set repository secret `HF_TOKEN`.

## Verify

```bash
# Manifest
curl -fsSL \
  https://huggingface.co/datasets/yassercherfaoui/ishamela-bundles/resolve/main/catalog/catalog.json \
  | head

# App — use the default HF URL (no CATALOG_BASE_URL override)
cd ../app
flutter run -d macos
```

Smoke corpus (≥ 3 books) is enough for staging. Full corpus (~8,589) is a
production publish; do not commit `.isb` or book text into this git repo.
