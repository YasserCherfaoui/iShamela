# Changelog

All notable changes to this project are documented in this file.

## Unreleased

### Added

- Spec for live catalog publish & library selection ([`SPEC-007-live-catalog.md`](docs/specs/SPEC-007-live-catalog.md)): HF publish pipeline, production catalog URL, browse/select by category·author·title, batch download enqueue.
- Data audit (SPEC-006): `data/audit/audit_d1.py` + `audit_pdfs.py` with pinned HF revisions and committed outputs under `data/audit/out/`; `docs/DATA_SOURCES.md` rewritten to the SPEC-006 structure (topology, schemas, codepoints, D1×D2 overlap, licenses).
- App foundation (SPEC-004): Flutter shell with Riverpod, catalog sync (`core/net`), browse/search (RTL ar/en/fr), download queue (max 2, Range resume), sha256 verify, zstd install via embedded `zstandard_*` FFI (growing output buffer; avoids plugin `×20` helper). Task 0 evidence in `docs/ZSTD.md`. macOS Runner grants `network.client` (sandbox) and `NSAllowsLocalNetworking` for local catalog E2E.
- Library catalog builder (SPEC-003): `ishamela-catalog` merges SPEC-002 sidecars with HF `_meta` parquets into `catalog.json` + `catalog.sqlite.zst` (contentless FTS5 over normalized title/author). JSON Schema at `data/schemas/catalog.schema.json`. `CATALOG_SCHEMA_VERSION` is `1`.
- Book bundle builder (SPEC-002): `ishamela-build` CLI builds per-book SQLite+FTS5 bundles from `AuthenticIlm/Shamela4_Full_DB`, compressed to `.isb` (zstd level 19) with JSON sidecars. Schema gate documented in `docs/DATA_SOURCES.md`. `SCHEMA_VERSION` is `1`.
- Arabic search normalizer (SPEC-001): deterministic `normalize()` in Python (`ishamela_data.normalizer`) and Dart (`app/lib/core/search/normalizer.dart`), locked together by `shared/norm_test_vectors.jsonl`. `NORM_VERSION` / `normVersion` is `1.0.0`.
