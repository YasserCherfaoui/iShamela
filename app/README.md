# iShamela app

Flutter client (SPEC-004 foundation). Reader UI is SPEC-005.

## Run

```bash
cd app
flutter pub get
flutter analyze
flutter test

# Local E2E against data/dist (after building catalog + book_1.isb):
#
#   Terminal 1 — must be running while the app syncs:
#     cd data/dist && python3 -m http.server 8000
#   Terminal 2 — full rebuild so macOS entitlements pick up network.client:
#     cd app && flutter run -d macos --dart-define=CATALOG_BASE_URL=http://127.0.0.1:8000/
#
# Expect GET http://127.0.0.1:8000/catalog/catalog.json then catalog.sqlite.zst.
# Without the local server (or without network.client entitlement) the UI shows
# the offline empty state by design (SPEC-004: silent sync failure).
flutter run -d macos --dart-define=CATALOG_BASE_URL=http://127.0.0.1:8000/
```

Default catalog URL: `https://huggingface.co/datasets/ishamela/bundles/resolve/main/` (SPEC-007 publish).

## Layout

See `docs/specs/SPEC-004-app-foundation.md`. Zstd choice: `docs/ZSTD.md`.
