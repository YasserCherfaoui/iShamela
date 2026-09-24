# Changelog

All notable changes to this project are documented in this file.

## Unreleased

### Fixed

- iOS reader: honorific ligatures (ﷺ and the U+FD40–U+FD4F forms) fall back to Scheherazade New so they no longer render as squares. Amiri does not include those glyphs, and iOS does not substitute them the way macOS does.
- macOS auth: Debug/Profile signed with the development team so Google Sign-In keychain + Sign in with Apple entitlements work; Google `serverClientId` (web OAuth client) so Firebase gets an ID token; richer auth error console logs.

### Added

- Library sync (SPEC-025): account bookshelf in `users/{uid}/library`, per-device exclusions, auto-download on Wi-Fi (cellular respects the data toggle), first-sign-in sheet over 150 MB, storage preflight, and «إزالة من كل الأجهزة».
- Home screen (SPEC-023): first tab «الرئيسية» with greeting + Hijri/Gregorian date, continue-reading card, weekly streak/minutes/pages chips, recent history, bookmarks/notes quick actions, and guest sync banner. Shell tab order is Home · Library · Catalog · Settings (Downloads reachable from Settings).
- User profile (SPEC-024): guest + signed-in variants with lifetime stats (Arabic-Indic digits), sync controls, shortcuts, and account management (sign-out / change password / delete account); Settings → الحساب entry.
- Accounts & authentication (SPEC-022): Firebase Auth (Apple / Google / email+OTP), AuthWelcomeScreen, guest mode, and local→cloud merge scaffolding (`AuthController.syncNow`).

### Changed

- OTP email: send directly via **Resend** from Cloud Functions (no Firebase Trigger Email extension / `mail/` queue). Set secret `RESEND_API_KEY` before deploy.
- Platform SDK floors for FlutterFire: macOS 10.15, iOS 15.0, Android `minSdk` ≥ 23.
- Reader TOC bottom sheet: الفهرس / العلامات / الملاحظات tabs rebuild via `StatefulBuilder` (parent `setState` alone did not refresh the modal).
- Reader selection toolbar: **Remove highlight** when the selection overlaps existing highlights (deletes all overlapping rows; SPEC-010).
- Web reader: disable the browser context menu and show the highlight/note/cite toolbar when a text selection finishes (right-click still works too).
- Fix catalog/index row state after download (revision tick + treat `done` as installed); snackbar **افتح** uses the app navigator key so it can push the Reader.
- Download snackbar stays visible for the whole download (progress action = **عرض** only); after completion it morphs to **افتح** and remains ~10 s.
- Web (GitHub Pages / Vercel): launch the real app via WASM sqlite3 + IndexedDB VFS; **SPEC-021** enables the same Download → install → Reader path in the browser (origin storage), with optional `navigator.storage.persist()`.

### Added

- Accounts & authentication UI + controller (SPEC-022): optional Firebase guest-safe auth (`authProvider`), Apple/Google/email+OTP screens, merge/sync skeleton, ARB strings (ar/en/fr).
- Vercel deploy config: root `vercel.json` + `scripts/vercel-{install,build}.sh` (Flutter 3.32.5, `app/build/web`, SPA rewrite) so importing the repo builds the web app with no dashboard overrides.
- Brand assets, splash & download feedback (SPEC-020): Warm Manuscript icon (SVG→rasters script), native+Flutter splash, catalog affordance mapper + idempotent enqueue, themed download snackbar host.
- Storage manager (SPEC-015): `installed_size_bytes` on `state.sqlite` v7, Settings storage card, manage-storage screen with size-sorted uninstall.
- App language & About (SPEC-016): persisted `app_locale` (ar/en/fr), Settings language sheet, About with version/licenses/dataset attribution (`package_info_plus`, `url_launcher`).
- Library-wide text search (SPEC-017): Titles | Full text scope, streamed FTS across installed books (concurrency 2), exact-phrase chip.
- Author pages (SPEC-018): id-routed author screen with death-date contract, counts, embedded book list / download-all.
- Annotations export (SPEC-019): Markdown/plain export via share sheet (`share_plus`); Reader + Library menu entries.
- Reading history & page bookmarks (SPEC-014): `state.sqlite` v6 tables, coalesce/prune, History screen from Library hero «السجل», reader bookmark toggle + TOC pane tab; unit tests for history/bookmarks.
- DESIGN-002: history/bookmarks (SPEC-014) plus storage, language/About, library text search, author pages, annotations export (SPEC-015…019).
- DESIGN-001 gap close: floating selection toolbar; TOC indent + print page + notes badge; catalog FTS title highlight, `ت XXXهـ` / أجزاء meta, stale “N days” banner; downloads completed = check + افتح; reader wide inline search / labeled panes / ≥1200 defaults, gold footnote markers, بطاقة نسخ التوثيق; role colors `userOverride ?? themeDefault`; grids 2–3 col; subtle nav/page-pill/progress motion.
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

- Honorific role coloring now matches Shamela Unicode ligatures (`ﷺ`, `﷿`, `ﷻ`, U+FD40–U+FD4F, …) in addition to expanded Arabic phrases (SPEC-011).
- Splash waits for an explicit **ابدأ القراءة** / Start reading tap before entering Catalog (SPEC-020 SP-04); no auto-dismiss after load.
- Android NDK pinned to 27.0.12077973; iOS deployment target raised to 13.0 (zstandard_ios).
- GitHub Actions `Build & Release`: on each push to `main`, bump patch tag, build Android/macOS/Windows/web artifacts, publish a prerelease, and deploy web to GitHub Pages (`/iShamela/` base href). Windows runs on `windows-2022` (Flutter 3.32.x lacks VS 2026 support on `windows-latest`).
- CDN is `AuthenticIlm/Shamela4_Full_DB`; full browse catalog (8,589 books) built from `_meta` and shipped in `app/assets/catalog/`.
- Document catalog provenance: browse metadata comes from `AuthenticIlm/Shamela4_Full_DB` `_meta` at **build** time; the app syncs `catalog.json` / `catalog.sqlite.zst` and installs books by fetching `pages.jsonl` from the same dataset (SPEC-008). See SPEC-003/007/008, `docs/PUBLISH.md`, `docs/DATA_SOURCES.md`.
