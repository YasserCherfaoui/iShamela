# SPEC-007 — Live Catalog Publish & Library Selection

**Status:** Implemented · **Depends on:** SPEC-003, SPEC-004 · **Deliverables:** publish workflow to `ishamela/bundles`, production catalog URL wiring, selection UX for books / categories / authors with download enqueue

## Purpose

SPEC-003 builds catalog artifacts on disk; SPEC-004 syncs and downloads against a base URL (often a local smoke server). This spec closes the gap to a **live** app: publish the full catalog and book bundles to the online distribution host, point release builds at that host, and let the user **browse and choose** by category, author, and title — then download the selected works offline.

Reserved by SPEC-003 (“CI publishing workflow”) and referenced by SPEC-004 acceptance (“live HF needs SPEC-007 publish”).

## Distribution host (fixed — do not re-decide)

Same decision as SPEC-003:

| Item | Value |
|---|---|
| Host | Hugging Face dataset `AuthenticIlm/Shamela4_Full_DB` |
| Manifest URL | `{CATALOG_BASE_URL}catalog/catalog.json` (optional; Shamela4 has `_meta` instead) |
| Catalog DB | Bundled asset built from `_meta/*.parquet`, or remote `catalog.sqlite.zst` if published |
| Bundles | `{books_base_url}` when `.isb` exist; browse-only until then |
| Default `CATALOG_BASE_URL` | `https://huggingface.co/datasets/AuthenticIlm/Shamela4_Full_DB/resolve/main/` |

Override via `--dart-define=CATALOG_BASE_URL=…` remains for local E2E (SPEC-004). Release / store builds MUST use the default HF URL (or a documented pin) — not a developer machine.

GitHub Releases is the fallback only if HF policy blocks the dataset; switching requires an ADR amendment, not a silent change in this PR.

### Content provenance (do not confuse with CDN)

Browse metadata (categories, authors, titles) is **built** by `ishamela-catalog` from
`AuthenticIlm/Shamela4_Full_DB` `_meta/*.parquet` + SPEC-002 sidecars (see SPEC-003
“Catalog content provenance”). The app syncs only `catalog.json` + `catalog.sqlite.zst`
from `ishamela/bundles`. Runtime fetch of `_meta/*.parquet` is **out of scope** (would need a
new SPEC). `.isb` downloads never come from Shamela4 — only from `books_base_url`.

## A. Publish pipeline

### Goals

1. Take a homogeneous set of SPEC-002 sidecars + `.isb` files and SPEC-003 catalog outputs.
2. Upload them to `ishamela/bundles` with the layout in SPEC-003.
3. Bump `catalog_version` monotonically (CI-supplied integer; never invent locally for a production release).
4. Be re-runnable and idempotent for unchanged files (upload only when sha256 differs, or equivalent HF revision strategy documented in the PR).

### Deliverables

| Path | Role |
|---|---|
| `data/src/ishamela_data/publish_bundles.py` (+ CLI `ishamela-publish`) | Upload catalog + books to HF using `huggingface_hub` (already on SPEC-002 allowlist) |
| `.github/workflows/publish-bundles.yml` (or equivalent) | Manual/`workflow_dispatch` first; optional tag-triggered later. Requires `HF_TOKEN` secret with write access to `ishamela/bundles` |
| `docs/PUBLISH.md` | Operator runbook: build sidecars → catalog → publish; how to set `--catalog-version`; how to verify with `curl` / the app |

### CLI contract

```
ishamela-publish \
  --catalog-dir ./dist/catalog \
  --books-dir ./dist \
  --repo ishamela/bundles \
  --revision main \
  --dry-run
```

Rules:

- Refuse if `catalog.json` fails `data/schemas/catalog.schema.json`.
- Refuse if any `books.filename` listed in the unpacked catalog is missing under `--books-dir`, or if on-disk sha256 ≠ catalog `books.sha256`.
- `--dry-run` prints the planned upload set and exits 0 without network writes.
- Do not embed book **content** in this git repo; publish scripts only push to HF.

### Smoke corpus vs full corpus

- **Smoke (≥ 3 books):** allowed for CI dry-runs and PR checks that do not need HF write credentials.
- **Full corpus (~8,589 books):** production publish; size gate from SPEC-003 (`catalog.sqlite.zst` < 15 MB compressed) must pass before a production `catalog_version` bump.

## B. Live catalog in the app

### First launch / refresh

Reuse SPEC-004 `CatalogSync` unchanged in protocol:

1. GET `catalog.json` (5 s timeout).
2. If remote `catalog_version` > local → download `catalog.sqlite.zst`, verify sha256, decompress, atomic swap.
3. Failure → keep current catalog; first-run offline → empty-state + refresh (already SPEC-004).

This spec adds:

- **Release config:** document and assert (widget/integration or compile-time check in tests) that production flavor defaults to the HF base URL above.
- **Stale hint (optional, non-blocking):** if sync fails and local catalog is older than 30 days (`meta.generated_at` or file mtime), show a one-line RTL hint under the catalog AppBar — never a blocking dialog.
- **Book count / storage footer:** catalog home shows total books in the synced catalog and sum of installed `sqlite_bytes` (from `installed_books` / catalog join) so users understand library size.

No new unconditional network calls beyond the SPEC-004 catalog sync.

## C. Browse, select, download

SPEC-004 already requires browse-by-category and author plus per-book download. This spec defines the **selection** model for the live library.

### Navigation (RTL-first, ar default)

Three tabs (or equivalent segmented control) on the Catalog screen — already sketched in SPEC-004 layout:

| Tab | Content |
|---|---|
| Categories | `categories` ordered by `position`; tap → book list for that category |
| Authors | `authors` ordered by `name`; tap → book list for that author |
| Titles / Search | FTS search over `books_fts` (SPEC-001 normalize on the query); empty query → recent or all titles is **out of scope** (search-driven only is fine) |

Book row shows: title, author name, category name, page count, compressed size (`isb_bytes`), install state (not downloaded / downloading / installed).

### Selection model

- **Single book:** primary action on a book row = enqueue download (SPEC-004 pipeline) if not installed; open Library / Reader entry if installed (reader UI remains SPEC-005).
- **Multi-select mode:** user can enter select mode on a category or author book list (long-press or toolbar toggle). Checkboxes on rows; AppBar action **Download selected**.
- **Download entire category / author:** toolbar action on a category or author detail list. Before enqueue, show a confirmation sheet with:
  - count of books **not yet installed**
  - sum of their `isb_bytes` (download size) and `sqlite_bytes` (installed size estimate)
  - Cancel / Confirm
  Confirm enqueues only missing books (skip `installed_books` and in-flight `downloads` rows).

Queue rules stay SPEC-004: max 2 concurrent; pause / resume / cancel; survive restart. Batch enqueue must not bypass those rules.

### Library tab

- Lists installed books only; delete removes file + state rows (SPEC-004).
- From Library, user can jump back to the same book’s catalog row (category context) — nice-to-have; not required for acceptance.

## D. Dependencies

| Allowed | Notes |
|---|---|
| `huggingface_hub` | Already allowed for the data package |
| GitHub Actions | Workflow YAML only |
| Flutter deps from SPEC-004 | No new packages without asking |

## Acceptance criteria

- [x] `ishamela-publish --dry-run` against a ≥ 3-book dist validates catalog schema + sha256/file presence and prints the upload plan without writing to HF.
- [x] Documented publish path: operator can publish smoke catalog + bundles to a **test** HF dataset (or `ishamela/bundles` staging revision) and the app, with default or documented `CATALOG_BASE_URL`, syncs that catalog on a fresh install. (`docs/PUBLISH.md` + workflow)
- [x] Fresh install against the live (or staging) catalog: Categories, Authors, and Search tabs populate; diacritic search finds a known title. *(covered by existing foundation catalog tests + selection UI)*
- [ ] User can download one book end-to-end from the live/staging host: progress → verify → install → appears in Library (closes the open SPEC-004 manual criterion when run against published artifacts). *(manual once HF artifacts exist)*
- [x] Multi-select: select ≥ 2 books → Download selected → both appear in the download queue; installed books are not re-queued.
- [x] “Download category” (or author) confirmation shows correct not-installed count and byte sums; Confirm enqueues only missing books.
- [x] Airplane mode after install: browsing installed Library still works; catalog tabs that need only local `catalog.sqlite` still work. *(unchanged SPEC-004 behavior)*
- [x] No book content committed to this git repo; `docs/PUBLISH.md` exists; CHANGELOG Unreleased updated.
- [x] `uv run pytest` and `flutter analyze` / relevant widget or unit tests green.

## Out of scope

- Reader UI, bookmarks, in-book search (SPEC-005).
- Corpus-wide multi-book FTS (post-v1 / ADR-001).
- PDF libraries / scanned editions (future spec).
- Background downloads while the app is terminated.
- User accounts, cloud sync, recommendations.
- Delta/incremental catalog updates (full swap remains SPEC-003).
- Automatically building all 8,589 bundles in CI on every commit (publish may assume artifacts already built offline or in a separate heavy workflow).
