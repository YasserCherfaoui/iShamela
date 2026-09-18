# SPEC-011 — Reader Text Roles & Style Settings

**Status:** Implemented · **Depends on:** SPEC-005, SPEC-009, SPEC-010 · **Deliverable:** display-only role coloring + Settings UI; `state.sqlite` style prefs

## Purpose

Color and weight classical Arabic reader text by **role** (titles, honorific formulae, punctuation, Quranic quotes), similar to desktop الشاملة, and let the user change those looks — plus **reader font** — in a **Settings** page. Storage of `pages.body` stays verbatim — styling is display-only.

## Roles

| id | Meaning | Detection (v1) |
|---|---|---|
| `body` | Default running text | Everything not classified below |
| `title` | Section / TOC titles | HTML whitelist: `<span data-type="title"…>` content (SPEC-009); takes **priority** over phrases |
| `honorific` | All fixed honorific / formula phrases | Single shared style for the whole phrase table (below) |
| `quran` | Quranic quote including ornate marks | Inclusive span between a pair of ornate parentheses U+FD3E / U+FD3F **in either order** (marks + all text between); unpaired mark colors only itself |
| `punctuation` | Punctuation & brackets | Explicit Unicode set (below); applied only where no higher role |

### Phrase table → role `honorific` (normative, longest-first)

Matching runs on **display text** (HTML tags stripped per SPEC-009) after a **display-fold**: strip tashkīl U+064B–U+065F, U+0670, and tatweel U+0640 only. Do **not** use SPEC-001 `normalize()`.

Phrases (all map to **`honorific`**; sort by length desc when matching):

- `صلى الله عليه وآله وسلم`, `صلى الله عليه وسلم`, `عليه الصلاة والسلام`
- `رضي الله عنهم أجمعين`, `رضي الله عنهما`, `رضي الله عنهم`, `رضي الله عنها`, `رضي الله عنه`
- `رحمه الله تعالى`, `رحمهما الله`, `رحمهم الله`, `رحمها الله`, `رحمه الله`
- `سبحانه وتعالى`, `تبارك وتعالى`, `عز وجل`, `عزوجل`

Non-overlapping: once a display index is claimed, later matches skip it. Priority: **title > honorific phrases (longest first) > quran spans > punctuation > body**.

### Punctuation set (normative)

ASCII: `. , ; : ! ? ' " ( ) [ ] { } / \\ - – — …`  
Arabic: `، ؛ ؟ ٪ ٫ ٬`  
Guillemets / quotes: `« » “ ” ‘ ’`  
Whitespace is never `punctuation`. Ornate Quran marks are handled by `quran`, not `punctuation`.

User-editable custom phrase lists are **out of scope** for v1 (fixed table only).

## Display line breaks

When building display text from `pages.body`:

- Preserve existing `\n`.
- Map `\r\n` and lone `\r` → a single display `\n` (Windows / legacy Shamela line endings).
- Whitelist `<br>` / `<br/>` → display `\n` (SPEC-009).
- Do not collapse multiple newlines into one (paragraph spacing stays).

## Style model

```json
{
  "title": { "color": "#0D5C3D", "bold": true },
  "body": { "color": "#1A1A1A", "bold": false },
  "honorific": { "color": "#1B7A4E", "bold": false },
  "quran": { "color": "#B8860B", "bold": false },
  "punctuation": { "color": "#888888", "bold": false },
  "font": "amiri",
  "font_size": 20
}
```

| field | Notes |
|---|---|
| role colors / bold | Missing keys → defaults; invalid hex → keep default color |
| `font` | `system` \| `amiri` \| `scheherazade` (default `amiri`) |
| `font_size` | Base size in logical px; default `20`; clamp 14…40 |

**Uniform metrics:** All roles share the same `fontSize` and `height` (and `StrutStyle` with `forceStrutHeight: true`) so selection rectangles have equal height. Title may use **bold** only — not a larger size.

Persisted key `reader_text_styles` in `settings` (SPEC-009). Legacy keys `salawat` / `radiyallah` / `rahimahullah` / `azza_wajal` / `quran_mark` in old JSON are migrated: first present color wins for `honorific` / `quran`.

## Bundled fonts (SPEC-005 slice)

Under `app/assets/fonts/` (OFL license text in `OFL.txt`):

| Family id | Files |
|---|---|
| `amiri` | `Amiri-Regular.ttf`, `Amiri-Bold.ttf` |
| `scheherazade` | `ScheherazadeNew-Regular.ttf`, `ScheherazadeNew-Bold.ttf` |

Declared in `pubspec.yaml` `flutter.fonts`. Offline-only — no runtime font CDN.

## Settings UI

- Bottom-nav **Settings** tab.
- **Font** dropdown: System / Amiri / Scheherazade New.
- **Font size** slider (14–40).
- Section «مظهر النص»: one row per role (`body`, `title`, `honorific`, `quran`, `punctuation`) — color + bold.
- **Reset** restores defaults (including font).

## Reader integration

- Role classification + styles feed `SelectableText.rich` spans (`AnnotatedBody`).
- Apply `fontFamily` / size / strut on the selectable text.
- SPEC-010 highlights remain `backgroundColor`; do not erase role foreground.
- Body offsets for annotations unchanged.

## Acceptance criteria

- [x] Title spans classify as `title`.
- [x] All phrase-table hits classify as `honorific` and share one style.
- [x] `﴿نص﴾` classifies marks **and** inner text as `quran`.
- [x] `\r` / `\r\n` / `<br>` produce visible line breaks in display.
- [x] Selection uses forced strut → equal-height selection rects across roles.
- [x] User can pick Amiri / Scheherazade / system; persists across restart.
- [x] Stored `pages.body` unchanged.
- [x] Unit tests for classifier + JSON migrate/merge; `flutter analyze` clean.

## Dependencies

Flutter: existing allowlist only. Fonts are static assets (OFL), not a new package.

## Out of scope

- User-defined phrase lists; per-book overrides.
- Sepia / dark theme palettes.
- Coloring from `services_raw` beyond `data-type="title"`.
