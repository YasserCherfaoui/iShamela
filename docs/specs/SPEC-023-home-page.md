# SPEC-023 — Home Screen (الرئيسية)

- **Status:** Implemented
- **Depends on:** SPEC-014 (reading history & bookmarks — data source), SPEC-005 (reader), SPEC-022 (auth, optional), DESIGN-001 tokens
- **Placement:** new **first tab** «الرئيسية» (rosette icon). Tab order becomes: الرئيسية · المكتبة · الفهرس · الإعدادات. App launches to Home; tapping the active tab scrolls to top.

## 1. Purpose

Turn the app's opening moment from "pick a book" into "continue your study": surface the last reading position, lightweight progress stats, and recent history — all computed **locally** from SQLite (works fully as guest); an optional sync banner ties into SPEC-022.

## 2. Layout (top → bottom, single scroll)

### 2.1 Header
- Right: «السلام عليكم» + display name when signed in («أهلًا، يوسف»), plain greeting as guest.
- Left: Gregorian + Hijri date line, small, muted (`intl` + `hijri` package; Hijri may be ±1 day — label it «تقريبًا» in a tooltip, no prayer times in scope).

### 2.2 Continue-reading card («متابعة القراءة») — hero
- Source: most recent row in reading history with a stored position.
- Contents: book spine (green `#0E3B30` mini-cover as in catalog), book title (Amiri 700), «كتاب … · باب …» crumb, «ج ٢ · ص ١٤٣», and a thin gold progress bar = page / total pages of the volume, with «٪٤٢» caption.
- Tap → opens the reader at that exact position. Trailing chevron button only; the whole card is the tap target.

### 2.3 Weekly stats strip (three tonal chips)
- **أيام متتالية** — streak: consecutive calendar days (device timezone) with ≥ 1 history entry, today counted once any entry exists.
- **دقائق هذا الأسبوع** — sum of session minutes, Mon–Sun. A session's duration = time between reader open and close/last page-turn, capped at 30 min idle.
- **صفحات هذا الأسبوع** — count of distinct (book, volume, page) visited this week.
- Numbers in Arabic-Indic digits. If SPEC-014 doesn't yet store durations, add `duration_seconds` to the history table (migration noted in §4) and show only streak + pages until populated.

### 2.4 «آخر القراءات» — recent history
- The 5 most recent history entries (excluding the hero's), grouped headers «اليوم / أمس / هذا الأسبوع»; row = small spine, title, position crumb, relative time; tap resumes at that position.
- Trailing «عرض الكل» → existing full History screen (SPEC-014).

### 2.5 Quick actions row
- Two tonal buttons: «العلامات» → bookmarks list, «ملاحظاتي» → notes list. (No new features — links only.)

### 2.6 Sync banner (conditional, dismissible per-version)
- Guest with ≥ 3 history entries: soft card «سجّل الدخول لمزامنة قراءاتك عبر أجهزتك» + button → AuthWelcomeScreen. Signed-in: replaced by nothing (sync status lives in Profile, SPEC-024).

## 3. Empty & edge states

- **Brand-new user** (no history): hero becomes an invitation card — rosette, «ابدأ رحلتك مع المكتبة», button «تصفَّح الفهرس» → catalog. Stats strip hidden; history section hidden; quick actions still shown.
- **Book deleted** after appearing in history: row stays, tap shows the SPEC-020 snackbar «الكتاب غير منزّل» with a «تنزيل» action deep-linking to its catalog entry.
- Loading: skeleton shimmer blocks in surface color; all queries are local and must render < 100 ms on mid-range hardware (indexes in §4).

## 4. Data

Local SQLite only (mirrored to the user's Firestore subtree via SPEC-022 §6 when signed in):

- `reading_history(id, book_id, volume, page, opened_at, duration_seconds NULL)` — **migration:** add `duration_seconds` if absent; backfill NULL.
- Derived queries (put in one `HomeStatsDao`):
  - last position: `ORDER BY opened_at DESC LIMIT 1`
  - streak: dates of history entries, walk back from today.
  - weekly minutes/pages: `WHERE opened_at >= start_of_week`.
- Index: `(opened_at DESC)`; all stats computed in one pass, cached in memory, invalidated on new history writes.

## 5. Theming & a11y

- Cards: `#FFFDF7` on Paper, `#EBDCBB` on Sepia, `#16241D` on Night; hairlines and gold accents per DESIGN-001. Progress bars always gold `#C6A15B`.
- Dynamic type: layout must survive +2 text scale steps; stats chips wrap to 2×2.
- Every card is one semantic button with a full Arabic label («متابعة قراءة رياض الصالحين، الجزء الأول، الصفحة ١٢»).

## 6. Acceptance criteria

1. App cold-starts into Home; guest and signed-in variants both render with no network.
2. Continue-reading card resumes the exact book/volume/page of the latest session.
3. Streak, minutes, pages match a hand-computed fixture dataset (unit tests on `HomeStatsDao`).
4. New-user empty state shows the invitation and no stats/history sections.
5. Deleted-book history rows degrade to the download snackbar, never crash.
6. Sync banner appears only for guests with ≥ 3 entries, dismiss persists for the app version, and never reappears once signed in.
7. All three themes + RTL verified; Home renders < 100 ms after warm-up on the reference device.

## 7. Out of scope

Prayer times, Qur'an-specific widgets, goals/targets ("read 10 pages a day"), social features. Candidate follow-ups once Home ships.