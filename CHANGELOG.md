# Changelog

All notable changes to this project are documented in this file.

## Unreleased

### Added

- DESIGN-001 screen restyles: Catalog brand header + segmented browse + book cards; Library continue-reading hero + spines/overflow; Downloads status cards; Settings atmosphere picker; Reader page-pill / jump+search sheets / atmosphere menu.
- DESIGN-001 foundation (Warm Manuscript): hand-authored theme tokens / atmospheres, bundled IBM Plex Sans Arabic, shared `lib/ui/` kit, adaptive HomeShell (bottom nav badge + ≥800 NavigationRail). Screen restyles follow.
- Downloads & Library UX (SPEC-013): Downloads tabs (active/failed/completed) with multi-select bulk actions and no progress on finished/failed; Library category/author/all-books tabs, search, bulk uninstall, hover/long-press book card. Library open uses lazy tab loading and batched catalog queries (no per-book SQLite opens).
- Reader: in-book search uses exact-token FTS MATCH (SPEC-005; no catalog prefix `*`) and snippets around the hit; bottom chrome shows print page, jump field, prev/next, and scrubber.
- Reader chrome (SPEC-012): full-text copy-with-reference; numbered note badges + Notes tab beside TOC; sticky TOC highlight; `pages.footnotes` (book schema 3) shown under body.
- Reader text roles & style settings (SPEC-011): unified honorific color, Quran spans (marks + inner text), Amiri/Scheherazade fonts + size, CRLF/`<br>` line breaks, equal-height selection strut; Settings tab.
- Reader annotations (SPEC-010): colored highlights, anchored notes, and copy-with-bibliographic reference; stored in `state.sqlite` (`highlights`, `text_notes`).
- Catalog UX: isolated search field (typing no longer loses focus), search retained on category/author book lists, select all / deselect all in multi-select, hide `0 pages` until a real count is known (catalog or installed).
- Shamela-like reader & catalog UX (SPEC-009): scoped catalog search (books/authors/categories), HTML whitelist body display, TOC + بطاقة panes, reading modes, in-book search; catalog schema 3 (`betaka_text`, author/category FTS); book schema 2 (`toc`, `source_page_id`).
- On-device install from Shamela4 (SPEC-008): catalog `source_pages_path` (schema v2), Dart `BundleInstaller` builds SPEC-002 SQLite+FTS from streamed `pages.jsonl`, `DownloadService` fetches pinned-revision Hub paths (no `.isb` CDN). Download UI gates on path presence, not `isb_bytes`.
- Minimal reader (SPEC-005 first slice): open installed books from Library / Catalog / Downloads; RTL page swipe; jump by print page number; last-read position in `reading_state`.
- Live catalog publish & library selection (SPEC-007): spec + `ishamela-publish` CLI, `docs/PUBLISH.md`, GitHub `publish-bundles` workflow; app multi-select / download-all with size confirmation, catalog footer + stale hint; default HF catalog URL covered by tests.
- Data audit (SPEC-006): `data/audit/audit_d1.py` + `audit_pdfs.py` with pinned HF revisions and committed outputs under `data/audit/out/`; `docs/DATA_SOURCES.md` rewritten to the SPEC-006 structure (topology, schemas, codepoints, D1×D2 overlap, licenses).
- App foundation (SPEC-004): Flutter shell with Riverpod, catalog sync (`core/net`), browse/search (RTL ar/en/fr), download queue (max 2, Range resume), sha256 verify, zstd install via embedded `zstandard_*` FFI (growing output buffer; avoids plugin `×20` helper). Task 0 evidence in `docs/ZSTD.md`. macOS Runner grants `network.client` (sandbox) and `NSAllowsLocalNetworking` for local catalog E2E.
- Library catalog builder (SPEC-003): `ishamela-catalog` merges SPEC-002 sidecars with HF `_meta` parquets into `catalog.json` + `catalog.sqlite.zst` (contentless FTS5 over normalized title/author). JSON Schema at `data/schemas/catalog.schema.json`. `CATALOG_SCHEMA_VERSION` is `2` (adds `source_pages_path` for SPEC-008).
- Book bundle builder (SPEC-002): `ishamela-build` CLI builds per-book SQLite+FTS5 bundles from `AuthenticIlm/Shamela4_Full_DB`, compressed to `.isb` (zstd level 19) with JSON sidecars. Schema gate documented in `docs/DATA_SOURCES.md`. `SCHEMA_VERSION` is `1`.
- Arabic search normalizer (SPEC-001): deterministic `normalize()` in Python (`ishamela_data.normalizer`) and Dart (`app/lib/core/search/normalizer.dart`), locked together by `shared/norm_test_vectors.jsonl`. `NORM_VERSION` / `normVersion` is `1.0.0`.

### Changed

- CDN is `AuthenticIlm/Shamela4_Full_DB`; full browse catalog (8,589 books) built from `_meta` and shipped in `app/assets/catalog/`.
- Document catalog provenance: browse metadata comes from `AuthenticIlm/Shamela4_Full_DB` `_meta` at **build** time; the app syncs `catalog.json` / `catalog.sqlite.zst` and installs books by fetching `pages.jsonl` from the same dataset (SPEC-008). See SPEC-003/007/008, `docs/PUBLISH.md`, `docs/DATA_SOURCES.md`.
