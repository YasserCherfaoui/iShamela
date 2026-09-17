# SPEC-004 — App Foundation: Architecture, Storage & Download Manager

**Status:** Ready for implementation · **Depends on:** SPEC-001, SPEC-003 · **Deliverable:** `app/` Flutter project skeleton with catalog sync, library storage, and bundle downloads working end-to-end (no reader yet)

## Purpose

Establish the Flutter application's structure and the full data path: fetch catalog → browse it → download a bundle → verify → decompress → open read-only. SPEC-005 builds the reader on top of this.

## Stack decisions (fixed — do not re-decide)

| Concern | Choice | Notes |
|---|---|---|
| Framework | Flutter (stable channel), Dart 3 | Targets: Android, iOS, Windows, macOS. Web deferred (ADR-001 §consequences) |
| State management | Riverpod (hooks optional) | Providers per feature; no global singletons |
| SQLite access | `sqlite3` package (direct, no ORM) | All DBs opened read-only except app-state DB |
| zstd decompression | Verification gate: candidate packages (`es_compression`, FFI bindings) must be evaluated on ALL 4 targets in Task 0; record the pick + evidence in the PR. If none is viable, escalate — fallback is switching bundle compression to gzip via a SPEC-002 amendment, a PM decision, not a dev improvisation |
| HTTP | `dio` | Needed for resumable range requests |
| Localization | `flutter_localizations` + ARB | UI languages: ar (default), en, fr. RTL-first |

## Project layout

```
app/lib/
├── core/
│   ├── db/            # sqlite open helpers, migrations for app-state DB
│   ├── search/        # normalizer.dart (SPEC-001) + offset-map extension (SPEC-005)
│   ├── models/        # Book, Category, Author, DownloadTask, ...
│   └── net/           # dio client, catalog client
├── features/
│   ├── catalog/       # browse categories/authors/titles, catalog search
│   ├── library/       # downloaded books, storage management
│   ├── downloads/     # queue UI + service
│   └── reader/        # (SPEC-005)
└── app.dart, main.dart
```

## App-state database (`state.sqlite`, read-write, versioned migrations)

```sql
CREATE TABLE downloads (
  book_id INTEGER PRIMARY KEY,
  status TEXT NOT NULL CHECK (status IN ('queued','downloading','verifying','installing','done','error','paused')),
  bytes_done INTEGER NOT NULL DEFAULT 0,
  bytes_total INTEGER,
  error TEXT,
  updated_at INTEGER NOT NULL
);
CREATE TABLE installed_books (
  book_id INTEGER PRIMARY KEY,
  schema_version INTEGER NOT NULL,
  norm_version TEXT NOT NULL,
  sqlite_bytes INTEGER NOT NULL,
  installed_at INTEGER NOT NULL
);
-- reader state (positions, bookmarks) is SPEC-005's concern; leave room via migrations
```

## Filesystem layout (app support directory)

```
<appSupport>/ishamela/
├── catalog/catalog.sqlite
├── state.sqlite
├── tmp/                      # partial .isb downloads (resumable)
└── books/book_<id>.sqlite    # decompressed, opened read-only
```

## Download pipeline (per book — the core of this spec)

1. `queued` → `downloading`: GET `books_base_url + filename` to `tmp/`, resumable via HTTP Range when `bytes_done > 0`.
2. `verifying`: sha256 of the complete `.isb` MUST equal `books.sha256` from the catalog; mismatch ⇒ delete file, `error`.
3. `installing`: decompress to `books/book_<id>.sqlite.part`, then atomic rename; open once, assert `meta.schema_version` is supported and `meta.norm_version == catalog norm_version` (mismatch ⇒ `error`, file removed).
4. `done`: row inserted in `installed_books`; catalog UI shows the book as available offline.

Rules: max 2 concurrent downloads; queue survives app restart (rebuilt from `downloads` table); user can pause/resume/cancel; cancel removes partials. Deleting an installed book removes the file and both table rows.

## Catalog sync

- On app start (and manual refresh): fetch `catalog.json` (timeout 5 s). Newer `catalog_version` ⇒ download `catalog.sqlite.zst`, verify sha256, decompress, atomic swap.
- Any failure ⇒ keep current catalog silently (log only). First-run with no network shows a friendly offline empty-state, not an error dialog.
- This is the app's only unprompted network call. No analytics, no telemetry, nothing else — enforced by review.

## Acceptance criteria

- [ ] Fresh install with network: catalog appears; browse by category and author; catalog search works with and without diacritics.
- [ ] Download a real bundle end-to-end on Android + one desktop target: progress UI, kill the app mid-download, relaunch, resume completes, hash verifies.
- [ ] Corrupted `.isb` (flip one byte in a test fixture) is rejected at `verifying` with a user-visible error and no leftover files.
- [ ] Airplane mode after install: catalog browsing of installed books and opening a book's DB still work.
- [ ] `norm_version` mismatch fixture is rejected at `installing`.
- [ ] `flutter analyze` clean; feature services covered by unit tests with mocked dio/filesystem.

## Out of scope

- Reader UI, in-book search, bookmarks (SPEC-005).
- Corpus-wide multi-book search (post-v1).
- Background downloads while app is terminated (platform work, future spec).