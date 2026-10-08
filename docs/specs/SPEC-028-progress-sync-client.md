# SPEC-028 — Crash-safe Reading Progress & Sync Client (Flutter)

- **Status:** Draft
- **Implements:** ADR-003 (client side), replaces the Firestore sync layer described in SPEC-024/025
- **Server contract:** SPEC-027 §5.4, §5.5, §7

## 1. Problems this spec solves

1. **Progress lost on unexpected close.** The position must survive a force-quit, OS kill, or crash — with or without an account, with or without network.
2. **Sync felt slow.** Login and app start waited on the network. After this spec, no screen ever waits on sync; sync is a background side effect of local writes.
3. **"Reference peek" overwrote real progress.** Opening a book at a random page (search hit, footnote, bookmark, "check a reference") must not move the resume position unless the user actually reads there.

## 2. Principles

- **Local-first, always.** Every state change is written to the on-device SQLite (the existing app DB, not the book bundles) synchronously on the UI action. The network never sits between a user action and its persistence.
- **Outbox pattern.** Every local write of a synced table also appends a row to `sync_outbox`. A background worker drains the outbox to the server; the server's pull feeds changes back into the local tables.
- **Guest mode unchanged.** Without an account the outbox is simply never drained (and is pruned). On sign-in, the outbox is replayed so the user's guest data reaches the account.

## 3. Reading progress — the qualification rule

Two distinct concepts:

| Concept | Storage | Synced | Meaning |
|---|---|---|---|
| **Viewport** | in-memory + `book_session` table | no | The page currently on screen. Updated on every page change. |
| **Progress** | `reading_progress` | yes | The page the user *was reading*. This is what "Continue reading" and cross-device resume use. |

A viewport page becomes **Progress** when either:

- (a) it has been on screen for **≥ 8 seconds** with the app in the foreground, or
- (b) the user has turned **≥ 2 consecutive pages** forward or backward from it (i.e. is clearly paging through), in which case the *current* page qualifies immediately on each further turn.

When a page qualifies, write `reading_progress` locally with `page` and `progress_at = now()` and enqueue an outbox row targeting the **beacon** endpoint.

Consequences:
- Opening a book from search/bookmark/reference at page 300 and closing it 3 seconds later leaves progress untouched.
- Landing on a page and reading it qualifies it after 8 s — no user action required.
- Progress is per `(book_id)`, one row, last qualified page wins by `progress_at` — on this device and across devices.

**Peek mode UI:** when a book is opened at a page ≠ stored progress, show a dismissible chip "Resume at p.{progress}" for the session. Tapping it jumps to progress. The chip disappears once the current page qualifies (the user has now chosen to read here).

Tunables (`ProgressPolicy` constants): `dwellSeconds = 8`, `consecutiveTurns = 2`. Not user-facing.

## 4. Local schema additions (app SQLite)

```sql
-- mirrors of the server tables, same columns as SPEC-027 §4 plus:
--   sync_state text check in ('synced','pending','conflict')   (informational)
reading_progress, reading_history_events, bookmarks, notes, bookshelf

book_session (                     -- not synced
  book_id text primary key, page int, volume int, scroll_offset real, updated_at
)

sync_outbox (
  id integer primary key autoincrement,
  kind text check in ('beacon','change'),
  table_name text, record_key text, payload_json text,
  created_at, attempts int default 0, last_error text null
)

sync_meta ( key text primary key, value text )   -- 'cursor' (server_seq), 'device_id', 'last_pull_at'
```

`book_session` is written on **every** page change (cheap single-row upsert). It is what restores the viewport after a crash even when the page never qualified as progress: on reopen, the reader goes to `book_session.page` if it exists, otherwise to `reading_progress.page`. So the user always lands where they were, while cross-device resume stays on real progress.

## 5. Write path

```
UI action
  └─ ProgressRepository.commit(page)         # sync, < 5 ms
       ├─ UPDATE reading_progress ... (local)
       ├─ INSERT sync_outbox(kind='beacon', ...)
       └─ SyncScheduler.nudge()              # debounce, see §6
```

Same shape for bookmarks/notes/history/bookshelf with `kind='change'`.

All local writes go through a single `AppDatabase` with `PRAGMA journal_mode=WAL; synchronous=NORMAL;` — durable enough for OS kills, and WAL keeps page-turn writes off the critical path.

## 6. Flush triggers (`SyncScheduler`)

The outbox is drained when **any** of these fires, whichever comes first:

| Trigger | Behaviour |
|---|---|
| `nudge()` from a write | debounce **3 s** — coalesces rapid page turns |
| Periodic while a book is open | every **60 s** |
| `AppLifecycleState.inactive` / `paused` / `hidden` | **immediate**, with a 4 s HTTP timeout (iOS grants ~5 s; enough for a beacon POST) |
| Book closed (reader popped) | immediate |
| App start / resume, and after sign-in | drain outbox, then full pull |
| Connectivity restored (`connectivity_plus`) | immediate |

Web additionally hooks `visibilitychange` and `pagehide` and uses `navigator.sendBeacon` for the beacon payload (fire-and-forget survives tab close). Implement via a small `dart:js_interop` shim; other platforms use the normal HTTP client.

Drain algorithm:
1. Take up to 50 `beacon` rows → one `POST /progress` (array form). Delete on 2xx.
2. Take up to 500 `change` rows → `POST /sync/push`. Delete `applied`; for `rejected: STALE` also delete (server has a newer version; it arrives on pull). Other rejections: keep, increment `attempts`, exponential backoff (max 10 attempts, then surface in Profile → "Sync issues").
3. `GET /sync/pull?since=cursor` until `hasMore=false`; apply records to local tables using the same LWW rule (`updated_at` / `progress_at` newer than local → overwrite; else ignore). Update `cursor`.

Order matters: beacons first (cheapest, most valuable), push before pull (so a device never re-downloads its own change as a "conflict").

Network calls use a 10 s timeout except the lifecycle flush (4 s). Failures are silent; never show a spinner for sync. The Profile screen shows "Last synced: 2 min ago" from `sync_meta.last_pull_at`.

## 7. Sign-in / sign-out / device switch

- **Sign-in:** set `device_id` (from `AuthResult.device.id`), re-tag all local synced rows with this `device_id`, enqueue every local row into the outbox as `change` (progress rows as `beacon`), then drain + pull. Guest data therefore merges into the account by LWW — a deliberate ADR-002 behaviour.
- **New device, existing account:** pull with `since=0`; bookshelf rows trigger SPEC-025 auto-download of missing bundles; progress applies once the bundle is installed.
- **Sign-out:** per SPEC-024 — ask "Keep data on this device?"; either way clear tokens, outbox, and `sync_meta`.
- **Account deletion:** call `DELETE /me`, then wipe synced tables, outbox, `sync_meta`, tokens. Guest mode resumes.

## 8. Tokens

- Access + refresh stored in `flutter_secure_storage` (Keychain / EncryptedSharedPreferences / IndexedDB-wrapped on web).
- An `AuthInterceptor` on the HTTP client attaches the access token, and on 401 performs a single refresh (`POST /auth/refresh`) and retries once. Concurrent requests share one in-flight refresh. A failed refresh signs the user out locally.

## 9. Testing

- Unit: qualification rule (dwell timer, consecutive turns, peek does not qualify, timer pauses when app backgrounded).
- Unit: outbox drain ordering, STALE handling, backoff, idempotent replay.
- Integration (against Compose backend): two simulated devices editing the same book; assert deterministic resume page.
- Manual QA script: open book → turn 3 pages → force-quit within 1 s → relaunch → lands on the same page (viewport) and, after ≥ 8 s dwell earlier, `reading_progress` matches on a second device after ≤ 60 s.

## 10. Acceptance criteria

- No UI path awaits a network call for progress, bookmarks, notes, history, or bookshelf.
- Force-quitting the reader at any moment loses at most the last page turn's *sync*, never its *local* persistence.
- A "peek" of < 8 s without paging never changes cross-device resume position.
- After app pause with network available, the latest qualified progress is on the server within 4 s.
- Cold start with a signed-in account renders Home from local data in < 300 ms, with sync running afterwards.