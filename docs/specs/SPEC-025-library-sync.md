# SPEC-025 — Library Sync & Auto-Download

- **Status:** Draft
- **Depends on:** ADR-002 (Firebase), SPEC-022 (auth + merge job), SPEC-015 (storage manager), catalog/download pipeline specs, SPEC-020 (download snackbar, idempotency)
- **Feeds:** SPEC-023 (Home missing-book rows), SPEC-024 (sync section)

## 1. Purpose

Make the **installed library part of the synced account state**: signing in on a new device replicates the user's bookshelf — books auto-download from HuggingFace (content never transits Firestore, per ADR-001) — and reading progress lands in those books so «متابعة القراءة» works immediately everywhere.

## 2. Data model

`users/{uid}/library/{bookId}`:

- `title` (denormalized for UI before catalog loads), `sizeBytes`, `catalogVersion`
- `status`: `installed` | `removed` (tombstone — see §4)
- `installedAt`, `updatedAt` (LWW key, like every synced doc)

Locally, a small `library_exclusions(book_id)` table records books the user removed **on this device only**; exclusions never sync.

Desired set for a device = docs with `status == installed` **minus** local exclusions.

## 3. Auto-download orchestration

Runs whenever the desired set contains books not installed locally — after the SPEC-022 §6 merge (first sign-in), on every sync tick, and on foreground.

1. **Enqueue** missing books into the existing download manager (same queue, resume, retry, and SPEC-020 progress snackbar; idempotency already prevents double-installs).
2. **Network policy:** start immediately on Wi-Fi. On cellular, download only if the SPEC-024 «المزامنة عبر بيانات الهاتف» toggle is on; otherwise hold the queue with a passive banner on the Downloads screen: «بانتظار شبكة Wi-Fi».
3. **Storage preflight:** sum of pending `sizeBytes` vs free space. If insufficient, don't start silently — sheet: «المساحة غير كافية لتنزيل مكتبتك (٣٤٠ م.ب مطلوبة)» with [اختيار الكتب] (multi-select) and [إدارة التخزين] (SPEC-015).
4. **First-device-setup sheet:** on first sign-in only, if the desired set totals **> 150 MB**, show a one-time sheet «تنزيل مكتبتك — ١٢ كتابًا · ٣٤٠ م.ب» with [تنزيل الكل] (default) / [اختيار] / [لاحقًا]. Under the threshold, or for later single-book additions from other devices, downloads start silently under the network policy.
5. **Progress application:** synced `progress`/`history` docs are written to SQLite regardless of install state. A book's «متابعة القراءة» card and history rows render before its download finishes; tapping one mid-download opens the Downloads screen focused on that book, and after install the reader resumes at the synced position (SPEC-023 §3 missing-book behavior upgraded from "snackbar + CTA" to "jump to its active download" when one is running).

## 4. Install / removal semantics

- **Installing** a book on any signed-in device upserts its library doc (`status: installed`) → other devices pick it up on their next sync tick and enqueue it.
- **Removing** a book (storage manager or long-press) is **this-device-only by default**: adds a local exclusion, frees the files, leaves the doc untouched — other devices keep the book, and this device won't re-download it.
- The removal sheet offers a second, explicit action **«إزالة من كل الأجهزة»** → writes `status: removed` (tombstone). Other devices delete local files on next sync and drop any exclusion rows for it. Re-installing later flips the same doc back to `installed`.
- Guest mode: no library docs exist; install/remove stays purely local, exactly as today. On first sign-in the merge (SPEC-022 §6) seeds `library/` from locally installed books (union with any existing account library).

## 5. UI touchpoints (no new screens)

- Downloads screen gains a section header «مزامنة المكتبة» over auto-enqueued items, with a "pause all / resume all" that already exists in the manager.
- Catalog cards need no change: `installed` state derives from local files as today.
- SPEC-024 sync section gains one toggle: «تنزيل كتب مكتبتي تلقائيًا» (default **on**; off = library docs still sync, downloads become manual via the CTA rows).

## 6. Edge cases

- **Catalog version drift:** if a library doc's `catalogVersion` no longer exists upstream, download the current catalog's edition of the same `bookId` and update the doc; if the book vanished from the catalog entirely, keep the row visible in Downloads with «غير متوفر حاليًا» and no retry loop.
- **Simultaneous first sign-ins** on two devices with different local books: both merges union into `library/` (set-union is naturally commutative; LWW only arbitrates per-doc fields).
- **Quota safety:** library docs are tiny; a 500-book shelf is ~500 docs — well inside Firestore free-tier reads at our sync cadence (one query per tick, cached snapshot listener preferred).

## 7. Acceptance criteria

1. Device A installs 3 books as a signed-in user → device B (same account, Wi-Fi, auto-download on) has all 3 installed within one sync tick, no user action.
2. Fresh sign-in on an empty device with a 12-book / >150 MB account shows the setup sheet; [تنزيل الكل] installs everything; [لاحقًا] leaves CTA rows that install on tap.
3. Reading position made on device A appears in device B's continue-reading card even while the book is still downloading, and the reader opens at that position once installed.
4. Per-device removal frees space locally, never removes the book elsewhere, and the book is not re-downloaded on this device on subsequent syncs.
5. «إزالة من كل الأجهزة» removes files on every signed-in device on its next sync.
6. Cellular with the data toggle off: queue holds with the waiting banner; flipping the toggle or joining Wi-Fi starts it without reopening the app screen.
7. Insufficient storage triggers the selection sheet, never a failed silent loop.
8. Guest behavior is byte-for-byte unchanged.

## 8. Out of scope

Selective per-device "sync profiles" (e.g. "phone gets hadith only"), P2P transfer between devices, background OS-scheduled downloads while the app is killed (platform work — candidate follow-up with `workmanager`/BGTaskScheduler once v1 ships).