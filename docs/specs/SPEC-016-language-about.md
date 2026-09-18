# SPEC-016 — App Language & About

**Status:** Implemented · **Implements:** DESIGN-002 F4 (§5) · **Depends on:** existing ARB set (`app_ar/en/fr.arb`), settings store
**Goal:** Let users switch the app UI language (ar/en/fr) and give the app a proper About surface with version, licenses, and dataset attribution. No new features beyond that.

---

## 1. Language switching

- **LN-01** New persisted setting `appLocale ∈ {ar, en, fr}`; default `ar` (unchanged current behavior). Stored with the existing settings mechanism.
- **LN-02** Settings card **اللغة والتطبيق** row **لغة التطبيق** shows the current language name in its own language (العربية / English / Français) + chevron → bottom sheet with a 3-option radio list. Selection applies **immediately** (no restart): `MaterialApp.locale` bound to the provider.
- **LN-03** Chrome text direction follows the selected locale (RTL for ar, LTR for en/fr). **Reader content column stays RTL always** — body text, footnotes, TOC titles, بطاقة content are Arabic corpus data regardless of UI language.
- **LN-04** Mixed-direction guards audited on switch: the existing LTR isolates for `current/total` remain; page labels and counts in chrome use the locale's digits (Arabic-Indic in ar, Western in en/fr) via `intl` NumberFormat. Verbatim body text is never reformatted (per data contract).
- **LN-05** RTL-mirrored assets: chevrons/back arrows already flow from `Directionality`; the custom SVG icon set must use direction-aware widgets (e.g. `matchTextDirection`) — audit item in the PR checklist.
- **LN-06** Translation completeness: CI gate — `untranslated_messages.yaml` must be empty for the three locales before ship; runtime fallback order ar → en for any key that slips through.
- **LN-07** Locale change does not disturb reader state, downloads in progress, or search results already on screen (they re-render labels only).

## 2. About screen (حول التطبيق)

- **LN-10** Entry: row **حول التطبيق** in the اللغة والتطبيق card → pushed screen.
- **LN-11** Content, top to bottom:
  - Rosette + wordmark (brand mark from DESIGN-001).
  - App name + `الإصدار {version} ({build})` via `package_info_plus`.
  - **Dataset attribution block (required):** "بيانات المكتبة الشاملة — مجموعة AuthenticIlm/Shamela4_Full_DB على HuggingFace" + tappable link; one line noting texts are displayed verbatim from the corpus.
  - Open-source: license name + repository link.
  - Row **تراخيص الطرف الثالث** → Flutter `showLicensePage` (themed with app colors).
- **LN-12** Links open externally (`url_launcher`); offline tap → snackbar "لا اتصال بالإنترنت" and no navigation.
- **LN-13** A long-press on the version line copies `version+build` to clipboard (support/debug convenience) with snackbar.

## 3. Acceptance criteria

1. Switch ar→fr: entire chrome flips to LTR French within one frame chain; reader page open in background remains RTL Arabic; return to ar restores Arabic-Indic digits everywhere in chrome.
2. Kill + relaunch after switching → app boots in the chosen locale.
3. All strings on every screen resolve in all three locales (CI gate green).
4. About shows correct semver/build on all 4 platforms; licenses page opens themed.
5. Downloads running during a locale switch continue and their status strings re-render localized.

## 4. Tests

Unit: locale provider persistence, digit formatting per locale. Widget: radio sheet selection, About content, mixed-direction golden tests for Downloads row and reader bottom bar in fr. Integration: switch-relaunch persistence.

## 5. l10n keys

`languageAndApp, appLanguage, aboutApp, version, buildCopied, licenses, datasetAttributionTitle, datasetAttributionBody, sourceCode, noConnection` (+ language display names are hard-coded endonyms, not translated keys).

## 6. Open questions

- OQ-1: should reader **chrome** (top/bottom bars) also localize, or stay Arabic like content? Current spec: it localizes with the app (it is chrome). Flag for Ladj if the scholarly audience prefers all-Arabic reader chrome.