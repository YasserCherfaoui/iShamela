# SPEC-015 — Storage Manager

**Status:** Implemented · **Implements:** DESIGN-002 F3 (§4) · **Depends on:** SPEC-013 (uninstall), catalog install registry
**Goal:** Give users visibility into disk usage of installed book bundles and a fast way to reclaim space, without touching the download pipeline or bundle format.

---

## 1. Scope

In: per-book and aggregate size display, device free-space display, single and bulk uninstall from a dedicated screen, Settings entry card.
Out: cache clearing, catalog DB management, cloud anything, download concurrency settings.

## 2. Data & size accounting

- **ST-01** Installed size per book is recorded **at install time** in the app DB (column `installed_size_bytes` on the installed-books registry; migration adds it). It is the sum of the bundle file(s) on disk after install completes.
- **ST-02** Backfill: on first run after migration, a one-shot background task `stat`s existing bundles and fills missing sizes. UI shows "—" for a book until its size is known; totals exclude unknown sizes with a caption "يجري حساب الأحجام…" while backfill runs.
- **ST-03** Sizes are invalidated and re-recorded on redownload/reinstall; deleted on uninstall.
- **ST-04** Device free space read via platform API (`disk_space`-style plugin or platform channel). Read failure → hide the free-space line silently; never block or crash.
- **ST-05** All size computations run off the UI thread; totals are a single SQL `SUM`.

## 3. Settings entry (card "التخزين")

- **ST-10** Card shows two lines: `المستخدم: {size} ({n} كتابًا)` and `المتاح على الجهاز: {size}`, plus tonal button **إدارة التخزين** pushing the manager screen.
- **ST-11** Lines are reactive: update after any install/uninstall completes.

## 4. Manager screen

- **ST-20** Header: back + **إدارة التخزين** + تحديد (select mode toggle).
- **ST-21** Summary block: 5px bar (fill = used ÷ (used + free), `green700`), caption `١٫٢ ج.ب مستخدمة · ١٨ ج.ب متاحة`. If free space unknown, bar hidden, caption shows used only.
- **ST-22** List = installed books **sorted by size desc** (ties: title). Row = spine + title + `{parts} · {category}` subtitle + trailing size (600 weight). Row overflow (⋯): **إلغاء التثبيت** · **بطاقة الكتاب**.
- **ST-23** Uninstall (single): reuses the SPEC-013 flow unchanged; confirm dialog additionally states the size to free: `سيحرر ١١٠ م.ب`.
- **ST-24** Select mode: checkbox rows, header actions حدد الكل / إلغاء التحديد / **إلغاء تثبيت المحدد (n)**; confirm dialog shows aggregate size. Bulk uninstall = sequential SPEC-013 uninstalls; progress via existing snackbar/pattern; partial failure reports which books remained.
- **ST-25** After any uninstall, list, summary bar, Settings card, and Library update reactively (shared providers — no manual refresh).
- **ST-26** Empty state (nothing installed): rosette + "لا كتب مثبّتة" + tonal button to Catalog.

## 5. Formatting

- **ST-30** Sizes use the existing byte-formatting helper (م.ب / ج.ب, one decimal ≥1 ج.ب); digits follow app locale (Arabic-Indic in ar). `used/free` style pairs keep the LTR-isolate rule where mixed with Latin digits.

## 6. Acceptance criteria

1. Fresh install of a 63 MB book → row appears with 63 م.ب within one frame of install completion; totals increase accordingly.
2. Bulk-uninstall of 3 books frees exactly the sum shown in the confirm dialog; Library no longer lists them; reading history rows for them flip to the "غير مثبّت" state (SPEC-014).
3. Airplane mode: whole screen fully functional.
4. Free-space API failing (mocked) → screen renders without the free line, no error UI.
5. 200 installed books: screen opens < 200 ms after data load; scrolling 60 fps (list is virtualized, sizes come from DB, not `stat`).

## 7. Tests

Unit: size backfill task (missing/partial/complete), SUM totals, sort comparator. Widget: row states, select-mode flows, confirm copy includes size. Integration: install→uninstall round trip updates all three surfaces.

## 8. l10n keys

`storage, storageUsed, storageAvailable, manageStorage, calculatingSizes, uninstallSelected, uninstallConfirmSize, freeUpSpace, noInstalledBooks`

## 9. Open questions

- OQ-1: expose per-book breakdown (bundle vs FTS index) if bundles ever split files? (Assume single figure for now.)