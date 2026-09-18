# iShamela app

Flutter client (SPEC-004 foundation). Reader UI is SPEC-005.

## Run

```bash
cd app
flutter pub get
flutter analyze
flutter test

# Default CDN = AuthenticIlm/Shamela4_Full_DB
flutter run -d macos
```

Catalog (8,589 books / 40 categories) is built from that dataset’s `_meta`
parquets and shipped in `assets/catalog/`. Refresh installs the bundled catalog
when the Hub has no `catalog.json` (normal for Shamela4 today).

Local override (optional smoke server):
`--dart-define=CATALOG_BASE_URL=http://127.0.0.1:8000/`

## Layout

See `docs/specs/SPEC-004-app-foundation.md`. Zstd: `docs/ZSTD.md`.
