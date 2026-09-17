# SPEC-001 — Arabic Search Normalizer

**Status:** Ready for implementation · **Depends on:** ADR-001 · **Deliverables:** `data/src/ishamela_data/normalizer.py`, `app/lib/core/search/normalizer.dart`, `shared/norm_test_vectors.jsonl`

## Purpose

A deterministic function `normalize(text: str) -> str` that maps Arabic text to a canonical search form. It is implemented **twice** (Python for the pipeline, Dart for the app) and both implementations MUST produce byte-identical output for the shared test vectors. It is applied to:

- the `body_norm` column at bundle-build time (index side), and
- user queries at search time (query side).

It is **never** applied to displayed text.

## Normative rules (apply in this order)

| # | Rule | Details |
|---|---|---|
| N1 | Remove tashkīl | Strip U+064B–U+065F (fathatan…sukun, etc.) and U+0670 (superscript alef) |
| N2 | Remove tatweel | Strip U+0640 |
| N3 | Remove Quranic annotation marks | Strip U+06D6–U+06ED, U+08D3–U+08FF (verify range coverage against test vectors) |
| N4 | Fold alef variants | أ (U+0623), إ (U+0625), آ (U+0622), ٱ (U+0671) → ا (U+0627) |
| N5 | Fold alef maqsura | ى (U+0649) → ي (U+064A) |
| N6 | Fold ta marbuta | ة (U+0629) → ه (U+0647) |
| N7 | Fold hamza carriers | ؤ (U+0624) → و (U+0648); ئ (U+0626) → ي (U+064A); standalone ء (U+0621) is **removed** |
| N8 | Normalize digits | Arabic-Indic ٠–٩ (U+0660–U+0669) and extended ۰–۹ (U+06F0–U+06F9) → ASCII 0–9 |
| N9 | Strip non-letter symbols | Remove punctuation (Arabic & Latin), ornate parentheses ﴿﴾ (U+FD3E/U+FD3F), brackets — replace with a space |
| N10 | Collapse whitespace | Any whitespace run → single U+0020; trim ends |
| N11 | Unicode NFC | Apply NFC normalization **before** N1 (presentation forms in the corpus must be decomposed/composed predictably) |

> ⚠️ Order matters and is part of the contract: NFC → N1..N9 → N10. Any change to rules or order bumps `NORM_VERSION`.

## Public API

**Python** (`ishamela_data.normalizer`):
```python
NORM_VERSION: str = "1.0.0"
def normalize(text: str) -> str: ...
```

**Dart** (`app/lib/core/search/normalizer.dart`):
```dart
const String normVersion = '1.0.0';
String normalize(String text);
```

No configuration options. No locale dependence. Pure function.

## Shared test vectors

File: `shared/norm_test_vectors.jsonl` — one JSON object per line: `{"in": "...", "out": "...", "note": "..."}`.

The implementer MUST create ≥ 40 vectors covering: fully vocalized Quranic text with ornaments, hamza on every carrier, tatweel-stretched words, mixed Arabic/Latin/digits, empty string, whitespace-only, text already normalized (idempotence: `normalize(normalize(x)) == normalize(x)` must hold for all vectors and is a required property test).

Both test suites (pytest & `flutter test`) load this same file. CI fails if either implementation diverges.

## Acceptance criteria

- [ ] All test vectors pass in Python and Dart implementations.
- [ ] Idempotence property test passes (hypothesis/fast_check-style over random Arabic strings is a plus, not required).
- [ ] `normalize` of a 3,000-word page completes in < 5 ms (Python, CPython 3.12) — it runs 7.6M times in the pipeline.
- [ ] Zero dependencies beyond the standard library (Python) / no packages (Dart).
- [ ] `NORM_VERSION` exported and documented.

## Non-goals

- Stemming, stop-word removal, root extraction (see ADR-001 §5 — post-v1, separate spec).
- Any mutation of displayed text.
