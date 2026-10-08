# SPEC-030 — Web app shell freshness

**Status:** Implemented. The two manual checks below still need a browser with an older service worker. · **Depends on:** ADR-001, SPEC-021 · **Deliverable:** Vercel and GitHub Pages load the deploy that was just published, including for a browser that still has the previous Flutter service worker

## Problem

The web app is a Flutter build. `main.dart.js` keeps the same filename every deploy. Two caches then keep the previous build running:

1. **Flutter’s service worker** (`offline-first`, the `flutter build web` default) serves `main.dart.js` and `flutter_bootstrap.js` from Cache Storage (`flutter-app-cache`) before the network. `index.html` is online-first. `skipWaiting()` runs on install, but an already-open page keeps executing the old script until it loads the new one.
2. **Vercel’s header** in `vercel.json` marks every `.js`, `.json`, and `.wasm` as `Cache-Control: public, max-age=31536000, immutable`. Those URLs are not content-hashed, so the CDN can keep serving the previous `main.dart.js` for a year. `cache: 'reload'` inside the service worker bypasses the browser cache and still receives that CDN copy.

GitHub Pages sends a short `max-age` (about 10 minutes) and cannot set per-file headers. The service worker is the part that matters there.

Flutter already writes `build/web/version.json` with `version` and `build_number` from `pubspec.yaml`. That file stays `0.1.0` / `1` across deploys, so it cannot name a build.

A tab left open on the previous build keeps doing whatever that build did. The Firestore `Listen` channel on project `shamelaonline` is that case: current `main` does not query Firestore, and a fresh load of the current Vercel deploy does not open `firestore.googleapis.com`.

Offline reading stays. Installed books live in IndexedDB (SPEC-021). This spec only changes how the **app shell** is cached. A device with no network must still open the last shell it successfully loaded.

## Build id

Both web hosts stamp the same id, the full git SHA from `git rev-parse HEAD` at build time.

| Piece | Rule |
|---|---|
| `--dart-define=APP_BUILD_ID=<sha>` | Passed to `flutter build web` on Vercel and in `.github/workflows/build-release.yml`. Local `flutter run` omits it. |
| `appBuildId` | `String.fromEnvironment('APP_BUILD_ID', defaultValue: '')` in `app/lib/core/config.dart`. |
| `app/web/index.html` | `<meta name="ishamela-build-id" content="__ISHAMELA_BUILD_ID__">` in `<head>`. |
| `build/web/shell-version.json` | Written **after** `flutter build web`, so it is not in the generated service-worker `RESOURCES` map. Body: `{"build_id":"<sha>"}` with no other fields. Trailing newline allowed. |
| `scripts/stamp-web-build.sh` | One script, called by `scripts/vercel-build.sh` and the Pages web job. Arguments: web output directory, sha. Replaces `__ISHAMELA_BUILD_ID__` in `index.html` and writes `shell-version.json`. If the sha is empty, write `build_id` as `""` and leave the placeholder so the client skips the check. |

`shell-version.json` is not a Flutter asset and is not listed in `pubspec.yaml`.

## Cache headers (Vercel only)

Remove the blanket immutable header on `js|wasm|data|json|png|…` from `vercel.json`.

Set `Cache-Control: public, max-age=0, must-revalidate` on these paths, relative to the site root (`--base-href /`):

- `/`
- `/index.html`
- `/flutter_bootstrap.js`
- `/flutter.js`
- `/flutter_service_worker.js`
- `/main.dart.js`
- `/version.json`
- `/shell-version.json`
- `/manifest.json`
- `/assets/AssetManifest.bin.json`
- `/assets/FontManifest.json`

Do not set `immutable` on any of those. Fonts, icons, and splash images may use `public, max-age=86400`. Their filenames are also stable; a day is the longest cache this spec allows for them.

GitHub Pages: do not add a headers file. Pages will not honor it.

Keep `flutter build web` on the default PWA strategy. Do not pass `--pwa-strategy=none`.

## Update check in `index.html`

A classic script in `app/web/index.html`, **before** `<script src="flutter_bootstrap.js">`, runs on every document load. It uses the page’s `<base href>` (relative URLs). No network call except what the browser already does for the document.

```
id = meta[name=ishamela-build-id]
if id is empty or still contains "__ISHAMELA_BUILD_ID__":
    load flutter_bootstrap.js
    stop

seen = localStorage["ishamela-build-id"]
if seen == id or localStorage throws:
    load flutter_bootstrap.js
    stop

localStorage["ishamela-build-id"] = id
if navigator.serviceWorker.controller is null:
    load flutter_bootstrap.js
    stop

unregister every service worker
delete Cache Storage keys that start with "flutter-"
if sessionStorage["ishamela-shell-reloaded"] == id:
    load flutter_bootstrap.js
    stop
sessionStorage["ishamela-shell-reloaded"] = id
location.reload()
```

`index.html` is online-first in Flutter’s worker, so a navigation with network receives this script from the new deploy. The worker still serves the old `main.dart.js` until the caches above are dropped and the page reloads once. The sessionStorage flag stops a second reload if unregister fails.

Offline, the worker’s online-first handler falls back to the cached `index.html`. That copy’s meta id matches `localStorage` from the last successful boot, so the script does not unregister and the cached shell still starts.

## Update check while a tab is already open

Web only, started from `main_web.dart` after `runApp`. No new pub package. Use `dart:js_interop` the same way as `storage_persist_web.dart`.

On `document.visibilitychange` to `visible`, and once at startup:

1. `GET` `shell-version.json` with `cache: 'no-store'`, URL relative to `<base href>`.
2. Parse `build_id` as a string. Any network error, non-200, or non-JSON: return. Do not reload.
3. Reload only when `shellBuildIsStale(appBuildId, buildId)` is true.

```dart
bool shellBuildIsStale(String runningBuildId, String? publishedBuildId) {
  if (runningBuildId.isEmpty) return false;
  final published = publishedBuildId?.trim() ?? '';
  if (published.isEmpty) return false;
  return published != runningBuildId;
}
```

This function lives in a file with no `dart:js_interop` import so `flutter test` can call it. Before `location.reload()`, set `sessionStorage["ishamela-shell-reloaded"]` to the published id. If that key is already the published id, do not reload again.

Reading position is already in `state.sqlite`. A reload returns the reader to the last saved page. Do not show a banner and do not wait for a tap.

`shell-version.json` is absent from the service-worker manifest, including manifests generated before this spec. The old worker does not intercept it (`RESOURCES` miss falls through to the network). That is why the open-tab check can see the new sha while `main.dart.js` is still the cached copy.

## Acceptance criteria

- [x] `scripts/stamp-web-build.sh` is what both `scripts/vercel-build.sh` and the web job in `.github/workflows/build-release.yml` run after `flutter build web`. Both pass the same `--dart-define=APP_BUILD_ID=`.
- [x] A stamped `build/web` contains `shell-version.json` whose `build_id` equals the meta content in `index.html`. The file is written after `flutter build web`, so `flutter_service_worker.js` `RESOURCES` does not list `shell-version.json`. `APP_BUILD_ID` is the same SHA passed to the stamp script.
- [x] `shellBuildIsStale` is unit-tested: empty running id, empty published id, equal ids, and different ids.
- [x] `vercel.json` no longer sends `immutable` for `main.dart.js` or `shell-version.json`. The shell paths in this spec use `max-age=0, must-revalidate`.
- [ ] With a warm `flutter-app-cache` from an older build, the next online load of `/` (Vercel) or `/iShamela/` (Pages) runs the new `main.dart.js` without a manual hard refresh. A second automatic reload does not happen.
- [ ] Airplane mode after one successful online load still opens the app and an installed book.
- [x] `flutter analyze` and `flutter test` pass. No new pub dependency.

## Out of scope

- Native, macOS, Windows, and iOS updates.
- Removing `cloud_firestore` / `firebase_auth` / `cloud_functions` from `pubspec.yaml` (SPEC-028 already requires that removal).
- Changing book downloads, IndexedDB books, or `pages.body`.
- Prompt copy, a “what’s new” screen, or a forced update for the native apps.
