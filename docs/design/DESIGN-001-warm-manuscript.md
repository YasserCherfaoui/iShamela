# DESIGN-001 — iShamela "Warm Manuscript" UI Redesign

**Status:** Foundation implemented · **Companion preview:** Claude Design canvas "iShamela UI Redesign" (artboards: design language, 8 phone screens, 1 desktop reader)
**Scope:** Visual system + screen redesign for the surfaces in `docs/CURRENT-UI-INVENTORY` §1. Preserves every functional behavior in inventory §12; targets every weakness in §13. No new product features beyond SPEC-005…013 (the sepia theme realizes SPEC-005's historical mention).

---

## 1. Visual direction — "Warm Manuscript"

A classical Arabic library, not a generic Material app: warm paper grounds instead of pure white, an evolved heritage green as the single brand hue, and gold reserved for what deserves gilding — Quranic text, reading progress, and small ornaments. Chrome is quiet (1px hairlines, no card shadows, one accent at a time) so Amiri-set titles and body text carry the identity. RTL-first everywhere; density drops from ListTile rows to breathing cards.

Three reading atmospheres (paper / sepia / night) share the same layout and tokens; only the color role values swap.

## 2. Token table

### 2.1 Color — light (chrome + paper reading theme)

| Token | Hex | Material 3 mapping | Use |
|---|---|---|---|
| `paper` | `#F6F1E7` | `surfaceContainerLowest` / scaffold bg | App ground |
| `readerPaper` | `#F8F3E6` | reader scaffold | Reader ground (slightly warmer) |
| `card` | `#FFFDF7` | `surface` | Cards, nav bar, fields |
| `hairline` | `#E4DBC8` | `outlineVariant` | 1px borders, dividers |
| `ink` | `#1F2A24` | `onSurface` | Primary text (chrome) |
| `muted` | `#6E7A70` | `onSurfaceVariant` | Secondary text, inactive icons |
| `green900` | `#0E3B30` | `onPrimaryContainer` / brand deep | Headers, active nav, hero card bg |
| `green700` | `#17614E` | `primary` | Filled buttons, active progress |
| `green100` | `#DFEBE2` | `primaryContainer` | Tonal buttons, active nav pill, chips |
| `gold` | `#A67C2E` | `tertiary` | Footnote markers, badges, rosette |
| `goldSoft` | `#C6A15B` | tertiary variant | Reading-progress fills, spine rules |
| `goldPale` | `#F4E9CF` | `tertiaryContainer` | "not started" chip bg |
| `quran` | `#8F6A1F` | text role default (themed) | Quran quotes on paper (was `#B8860B`; darkened for 4.5:1) |
| `highlight` | `#F3E2A9` | search-hit mark | FTS match highlight |
| `error` | `#A6402E` | `error` | Failed downloads, destructive text |
| `chipBg` | `#F0EADB` | `surfaceContainerHigh` | Meta chips |
| `segmentTrack` | `#EDE6D4` | `surfaceContainerHighest` | Segmented-control track, progress tracks |

Reader text roles keep their Settings defaults (`body #1A1A1A`, `titles #0D5C3D→#155744`, `honorifics #1B7A4E`, `quran #8F6A1F`) and remain user-overridable per role — the theme only supplies defaults per atmosphere.

### 2.2 Color — sepia & night reading themes

| Role | Sepia | Night |
|---|---|---|
| Ground | `#F1E5CC` | `#101B17` |
| Raised (pills/bars) | `#E9DAB9` | `#1B2A24` |
| Hairline | `#E0D2AF` | `#223229` |
| Body text | `#3A3226` | `#E7E1D2` |
| Titles | `#6B5220` | `#8FC7AC` |
| Quran | `#7A5A16` | `#D8B36A` |
| Honorifics | `#166844` | `#79B893` |
| Muted | `#8A7B5C` | `#7E9187` |
| Progress fill | `#A67C2E` | `#D8B36A` |
| Highlight (search) | `#E8D28A` | `#3D3421` + 2px gold underline |

Night highlights use a dark tint + gold underline rather than a light swatch so annotation colors stay legible; the 5 user highlight colors get desaturated night variants.

### 2.3 Type

| Style | Font | Size/weight | Use |
|---|---|---|---|
| Display | Amiri 700 | 26 | Tab page titles (الفهرس، المكتبة…) |
| Title | Amiri 700 | 22–23 | Pushed-page titles |
| Book title | Amiri 700 | 16–17 | Card titles |
| Reader body | Amiri (user) | 18 default, 14–40, lh 1.9 | Justified body |
| Reader chapter | Amiri 700 | body+2 | `span[data-type=title]` |
| Footnotes | Amiri | 14, lh 1.8 | Footnote zone |
| UI body | IBM Plex Sans Arabic 500/600 | 12–15 | Rows, buttons, labels |
| Caption | IBM Plex Sans Arabic 500 | 10.5–11.5 | Meta, counts, status |
| Brand mark | IBM Plex Sans Arabic 700 | 10.5, ls 2.5 | "iSHAMELA" + rosette |

Bundle Amiri + IBM Plex Sans Arabic as assets (offline-first — no runtime font fetching). Scheherazade New and System remain reader options.

### 2.4 Shape & space

| Token | Value |
|---|---|
| Radius | pill `999` · card `14–16` · field/button `12` · spine `6` · mini-preview `8` |
| Spacing scale | 4 · 8 · 12 · 16 · 20 · 24 (page gutter 20; reader gutter 24) |
| Borders | 1px hairline; **no elevation shadows** on cards; dashed hairline = unavailable |
| Touch | min 44×44 (icon buttons 38–44 with padding) |
| Ornament | 4-point rosette (gold), only: brand mark, chapter divider, empty states |

## 3. Component inventory (redesigned)

- **Bottom nav** — `card` bar, hairline top; active destination = icon in `green100` pill + 700 label in `green900`; inactive muted. Downloads shows a gold count badge while queue is active (fixes §13.4 discoverability + §3 "no badges").
- **Book card row** — generated **spine** (44×62, radius 6, category-hued solid: `#0E3B30 #114437 #5A4520 #1E4A56 #6E3A2C`, two gold hairlines + short Amiri word) + Amiri title + author (ت XXXهـ) + meta chips (أجزاء · size · قسم). Trailing is *one* thing: مثبّت chip / download tonal round button / 42px progress ring / nothing. Not-downloadable = dashed border, desaturated spine, "غير متاح للتنزيل" (fixes §5).
- **Category/author row** — tonal circle icon + name + count + chevron, as a card.
- **Search field** — one shared pill component everywhere (Catalog, book-list filter, Library, Reader top bar on wide): pill card, hairline, search icon, clear button; focused = 1.5px `green700` border (fixes §13.8).
- **Scope chips** — filled `green700` when active, hairline outline otherwise.
- **Segmented control** — `segmentTrack` pill track, active segment = white card chip with hairline; replaces Material TabBars in Catalog/Library/Downloads.
- **Buttons** — filled `green700`; tonal `green100`; ghost hairline; destructive is *text-only* in `error` (never a red filled button).
- **Download row card** — title + status line (colored by state) + 5px progress bar (green active / gold paused / none on failed-completed, per SPEC) + byte/ETA/speed caption + max **two** trailing round buttons (primary action + cancel); completed rows collapse to check-circle + افتح (fixes §13.4, §7 pain points).
- **Continue-reading hero** (Library) — `green900` card, gold "متابعة القراءة" eyebrow, gold progress + gold play FAB-let. Surfaces the existing per-book reading-state restore; no new data.
- **Library book row** — spine + thin gold progress bar + ٪; trailing overflow (⋯ → بطاقة / حذف) instead of an exposed delete icon per row.
- **Empty states** — rosette ornament + one line + one primary action (e.g. first-run Library: "مكتبتك فارغة بعد — تصفح الفهرس ونزّل أول كتاب" + tonal button to Catalog) (fixes §13.7).
- **Reader top bar** — back · centered Amiri title + `part · printPage` meta · search / TOC / ⋯ (بطاقة + reading mode live in ⋯ on phones; wide screens get labeled pill buttons) (fixes §13.5, §13.3).
- **Reader bottom bar** — 3px scrubber with gold fill + one row: prev/next round tonal buttons at outer edges (chevrons outward, RTL-correct) + center **page pill** "ج ١ · ص ١٢ · 12/745". Tapping the pill opens the jump sheet (print-page field + Go + TOC shortcut) — the inline field/Go/label row is gone from the bar (fixes the §9 bottom-bar pain). Print page shows "—" when null, never invented.
- **In-book search** — bottom sheet (field + exact-phrase chip + results with ص X + snippet), not a strip stealing page height.
- **Selection toolbar** — floating pill: 4–5 highlight dots · divider · note · copy-with-citation (see night artboard).
- **TOC pane** — indent tree, current section = `green100` pill row, print page numbers at the far edge; tabs الفهرس | الملاحظات (badge = note count).
- **Dialogs/sheets** — `card` bg, radius 16, title Amiri 700, confirm = filled green, destructive confirm = text in `error`.

## 4. Screen-by-screen notes

Match the artboards; deltas from today:

1. **Catalog** — brand mark + stats subtitle replace the plain AppBar + footer; segmented الأقسام/المؤلفون; category cards; stale banner becomes a slim gold-tinted card under search ("آخر تحديث قبل ٣٥ يومًا — حدّث الآن").
2. **Catalog search** — focused pill + scope chips; sectioned results with counts ("الكتب · ٤٢"); FTS matches marked with `highlight`; books keep their per-row install/download affordance inline.
3. **Book list** — labeled تنزيل الكل (tonal) + تحديد (ghost) buttons replace icon-only AppBar actions; select mode swaps trailing affordances for checkboxes and the button row for حدد الكل / نزّل المحدد (N) / إلغاء; confirm sheet unchanged in behavior.
4. **Library** — hero continue-reading card; per-book progress; overflow menu holds delete + بطاقة; long-press still enters select mode; بطاقة sheet shows spine + metadata + betaka excerpt (mobile parity with desktop hover, fixes §13.10).
5. **Downloads** — status cards as in §3 above; header shows active count + aggregate speed; "اكتمل اليوم" section keeps recent finishes one tap from the Reader.
6. **Settings** — new سمة القراءة theme picker (mini page-preview tiles) at top; خط القراءة card = font row + live Amiri preview + size slider with ا…ا endpoints; ألوان النص rows keep live preview + bold chip + swatch → existing picker dialog; reset stays top-left in `error` text.
7. **Reader phone** — see components; chapter opens with rosette divider; footnote zone titled الحواشي with gold (١) markers matching in-text superscripts.
8. **Reader ≥800dp** — 3 panes: TOC/notes (300) · centered page column (max 660) · بطاقة (300, with نسخ التوثيق); top bar gains inline search + labeled الفهرس/البطاقة toggles + theme toggle.

## 5. Responsive rules

| Width | Behavior |
|---|---|
| < 600 | Bottom nav; panes as sheets; page gutter 20 |
| 600–799 | Same shell; book lists go 2-col card grid; Settings cards max 560 centered |
| ≥ 800 | Reader: 3 panes (existing breakpoint kept). Catalog/Library/Downloads: `NavigationRail` (RTL: right edge) replaces bottom nav; content max 760 centered; book grids 2–3 col (fixes §13.9) |
| ≥ 1200 | Reader: both side panes open by default; page column max 660 |

## 6. Motion (subtle, purposeful)

- Tab change: 150ms fade-through; active nav pill grows from center (200ms `easeOutCubic`).
- Page turn (paged-H): existing RTL PageView; add 6px settle + page-pill number crossfade.
- Download progress: bars animate width; state changes (→paused) crossfade color 200ms.
- Continue-reading hero: gold progress animates to value on first build (400ms, once).
- Sheets: standard M3 spring; selection toolbar fades/scales 120ms from the selection point.
- Respect `MediaQuery.disableAnimations`.

## 7. Explicit non-goals

No social/feed features; no cover-image dependency (spines are generated); no change to storage-verbatim body rendering, print-page semantics, normalize-with-map offsets, FTS behavior, or download pipeline semantics; no light-on-dark chrome redesign beyond the three reading themes + matching chrome brightness; no new Settings sections beyond the theme picker.

## 8. Flutter implementation notes

- **One `ThemeData` per atmosphere** built from a hand-authored `ColorScheme` (not `fromSeed` — seed generation won't hit these exact warm neutrals). Map per §2.1 table.
- **`ThemeExtension`s:** `IshamelaTokens` (paper, hairline, gold, goldSoft, chipBg, segmentTrack, spine palette list) and `ReaderThemeTokens` (ground, raised, role-color defaults, highlight variants) so widgets never hard-code hex.
- **Shared widgets** (`lib/ui/`): `AppSearchField`, `SegmentedPills`, `BookCard` (+`BookSpine`), `MetaChip`, `TonalIconButton`, `ProgressRing`, `DownloadCard`, `SectionLabel` (label + hairline), `RosetteDivider`, `EmptyState`, `AppBottomNav` (badge param), `PagePill`, `JumpSheet`. Replace one-off styles with these; keep `Directionality.rtl` wrappers as today.
- **Spine color:** `spinePalette[category_id % 5]`; spine word = first meaningful title token (skip كتاب/ال… stop-words), 2-line Amiri, ellipsis.
- **Fonts:** `google_fonts` is fine for chrome in dev, but ship Amiri/IBM Plex Sans Arabic/Scheherazade New in `assets/fonts` for offline-first.
- **Nav badge:** `NavigationDestination` with a `Badge` bound to active-queue count provider (already derivable from `download_tabs.dart` statuses).
- **Reader themes:** reader Scaffold takes `ReaderThemeTokens`; role colors resolve as `userOverride ?? themeDefault`. Persist theme choice with existing settings store.
- **Jump sheet** replaces the inline field: reuse existing jump-to-print-page logic; snackbar "الصفحة غير موجودة" unchanged.
- **A11y:** keep LTR isolates for `current/total`; tooltips/labels on all icon buttons; contrast held ≥4.5:1 (muted `#6E7A70` on `#FFFDF7` passes; don't lighten further).

## 9. Weakness → fix trace (§13)

1 brand → wordmark/rosette/Amiri/warm palette · 2 lists → cards + spines · 3 icon-only actions → labeled buttons · 4 downloads clutter → status cards, ≤2 actions · 5 reader density → slim bar + jump/search sheets · 6 themes → paper/sepia/night · 7 empty states → rosette + guidance · 8 search → one shared field · 9 tablets → §5 rules · 10 book card on mobile → بطاقة sheet.