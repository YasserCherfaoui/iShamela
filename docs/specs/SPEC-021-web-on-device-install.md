# SPEC-021 — Web On-Device Install (WASM sqlite + IndexedDB)

**Status:** Implemented · **Depends on:** SPEC-008, SPEC-004, ADR-001 · **Deliverable:** same Download → install → Reader path on Flutter web (GitHub Pages / Vercel / local)

## Purpose

Web already opens catalog/state DBs via WASM sqlite + IndexedDB VFS. Book **install** was stubbed. This spec extends SPEC-008 so a web user can enqueue a download, build `books/book_<id>.sqlite` in the browser VFS, and open the Reader offline (same origin / same browser profile).

```
User taps Download (web)
  → GET pages.jsonl (+ optional toc.jsonl) into VFS tmp/
  → BundleInstaller builds SPEC-002/009 sqlite via WasmSqlite3
  → books/book_<id>.sqlite in IndexedDB VFS
  → installed_books + Reader open (read-only)
```

## Storage model

| Concern | Behavior |
|---|---|
| VFS | Existing `IndexedDbFileSystem` (`WebSqlite.init`) — same as catalog/state |
| Paths | Unchanged string layout under `/ishamela/…` (SPEC-004 / AppPaths) |
| Persist | Best-effort `navigator.storage.persist()` after first successful install (no new pub dependency; conditional web helper). Failure to persist is non-fatal |
| Quota | If the browser rejects a write / open with a quota-class error, mark download `error` with a short Arabic/English-capable message; do not leave a partial `installed_books` row |
| OPFS | Out of scope for v1 (IndexedDB VFS only) |
| File System Access API / “Save to disk” | Out of scope — installs stay in origin storage |

## Pipeline parity with SPEC-008

Statuses, concurrency (max 2), pause/resume/cancel, cancel-deletes-partials, and `body` verbatim rules are **identical** to SPEC-008.

Differences allowed on web only:

1. **No zstd** — continue fetching plain `pages.jsonl` / `toc.jsonl` (already SPEC-008 mode; no `.isb`).
2. **I/O** — all temp/dest paths go through `app_fs` / `openAppDatabase` (no `dart:io` `File` in shared install code).
3. **`canInstallOnDevice`** — true on web when `source_pages_path` is non-empty (same as native).

## API / code contracts

- `BundleDownloader.downloadToFile` takes a **string path** (append/resume via Range + `app_fs`).
- `BundleInstaller.installFromPagesJsonl` takes **string paths** and opens the part DB with `openAppDatabase`.
- Single `DownloadService` implementation for IO and web (no reject-all web stub).
- Reader / Library / FTS behavior unchanged once `book_<id>.sqlite` exists in the VFS.

## Acceptance criteria

- [x] SPEC-021 written; CHANGELOG *Unreleased* notes web install.
- [x] Shared DownloadService + BundleInstaller use string paths / `app_fs` (native FS or IndexedDB VFS).
- [x] Cancel mid-download leaves no `installed_books` row and no leftover book sqlite (covered by existing foundation tests).
- [x] Native path green: `foundation_test` download/install cases pass; `flutter analyze` clean; `flutter build web` succeeds.
- [x] No new pub dependencies.

## Out of scope

- Sharing installed books across browsers/devices; export of VFS DBs to disk.
- Changing CDN, revision pin, normalizer, or `pages.body`.
- Raising concurrency above 2; background Service Worker downloads.
- Guaranteeing installs of multi‑hundred‑MB books on low-quota browsers (document quota error only).
