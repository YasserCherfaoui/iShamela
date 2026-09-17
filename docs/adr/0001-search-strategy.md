# ADR-001: Search Strategy

**Status:** Accepted · **Date:** 2026-09-17 · **Deciders:** Project maintainers

## Context

Search is the core feature of iShamela. The corpus is large (8,589 books, ~7.6M pages of classical Arabic from `AuthenticIlm/Shamela4_Full_DB`) and the app must be offline-first and cross-platform (Flutter: Android, iOS, Windows, macOS, Web).

Classical Arabic search has specific requirements that generic engines don't handle out of the box:

- **Diacritics (tashkīl):** users type غفر and expect to match غَفَرَ.
- **Orthographic variants:** أ/إ/آ/ا, ى/ي, ة/ه, ؤ/ئ hamza forms must match interchangeably.
- **Tatweel (ـ)** and Quranic annotation marks must be ignored.
- **Root/derivational search** (find all derivations of غ-ف-ر) is a valued research feature; `Shamela4_Full_DB` ships a `root_dictionary.parquet` we can leverage.
- **Phrase and proximity search** matter for locating hadith wordings.

Constraints:

- Offline-first: a downloaded book must be searchable with zero connectivity.
- Mid-range mobile hardware: in-book search should feel instant (< 100 ms).
- No budget assumption: the project must work with zero paid server infrastructure; any server is optional enhancement.
- Full-corpus text is too large to require on every device; users download the books they study.

## Options considered

### A. On-device SQLite + FTS5 (per-book / per-collection indexes)

Ship each book as a SQLite bundle containing the source text plus an FTS5 index built over a **normalized shadow column** (diacritics stripped, variants folded). Corpus-wide search covers whatever the user has downloaded.

- ✅ Fully offline; zero infrastructure cost; SQLite runs on every Flutter target (incl. web via sqlite3 WASM).
- ✅ FTS5 is fast, mature, supports phrase/NEAR queries, and index build can happen at pipeline time (shipped pre-indexed) — no on-device indexing cost.
- ✅ Normalization is fully under our control in the data pipeline; the displayed text remains untouched (VISION principle: faithfulness).
- ⚠️ FTS5's default unicode61 tokenizer doesn't know Arabic; we must feed it pre-normalized text (or a custom tokenizer, which complicates builds).
- ⚠️ Corpus-wide search limited to downloaded content.

### B. Hosted search engine (Meilisearch / Typesense / Elasticsearch)

Index the full corpus server-side; app queries an API.

- ✅ Whole-corpus search including books not downloaded; typo tolerance; faceting.
- ❌ Breaks offline-first; recurring cost for ~7.6M documents (RAM-hungry at this scale); an ops burden misaligned with a volunteer open-source project.
- ❌ Single point of failure for the app's core feature.

### C. Embedded Rust engine (Tantivy via FFI)

- ✅ Very fast, sophisticated ranking.
- ❌ Heavy FFI/build complexity across 5 Flutter targets; poor web story; overkill versus pre-built FTS5 for per-book scale.

### D. Semantic/vector search

- ❌ Not a substitute for exact/normalized lexical search, which is what citation-driven research requires. Deferred; can layer on later (e.g., `Maktabati/shamela-vectors` exists as prior art).

## Decision

**Adopt Option A as the foundation: pipeline-normalized SQLite FTS5 bundles, built offline in CI and downloaded per book.**

Specifically:

1. **Two-column model per page:** `body` (verbatim source text, displayed) and `body_norm` (search text). FTS5 external-content table indexes `body_norm` only.
2. **Normalization pipeline (deterministic, versioned):**
   - strip tashkīl (U+064B–U+065F, U+0670) and tatweel;
   - fold أ/إ/آ → ا, ى → ي, ة → ه, ؤ → و + fold hamza forms consistently;
   - remove Quranic ornament marks; collapse whitespace.
   - The same normalizer (shared spec, tested against a golden file) runs on **user queries** at search time — index and query must normalize identically.
3. **Pre-built indexes:** FTS5 tables are constructed by the `data/` pipeline and shipped inside the bundle; the device never indexes.
4. **Multi-book search (v1):** iterate over downloaded bundles' FTS5 indexes and merge ranked results; benchmark before optimizing (BM25 scores from FTS5 are comparable enough across books of similar tokenization).
5. **Root search (post-v1):** use `root_dictionary.parquet` to expand a root query into its attested surface forms, then OR them into FTS5 — no morphological analyzer needed on-device.
6. **Optional online corpus search (post-v1, separate ADR):** if demand justifies it, a hosted search over the *full* corpus may be added as an enhancement — never a requirement — with the app degrading gracefully offline.

## Consequences

- The **normalizer becomes a critical shared artifact**: implemented once in the pipeline (Python) and once in the app (Dart), with a shared test-vector file to guarantee identical behavior. Any change bumps a `norm_version` stored in each bundle; app refuses to search bundles with an unknown version.
- Bundle size grows (~2× text weight for the shadow column + index); mitigated with SQLite page compression at download (bundles shipped as zstd archives) and by making `body_norm` contentless/external-content in FTS5.
- Search quality work (stemming beyond variant folding, stop-words for particles like و/ف prefixes) is contained inside the pipeline and can improve without app releases — a bundle version bump re-delivers better search.
- Web target must use sqlite3 WASM + OPFS; acceptable, but web is demoted to "best effort" for large libraries.

## First implementation tasks

1. `data/normalizer.py` + `test_vectors.jsonl` (golden normalization cases, incl. Quranic text edge cases).
2. `data/build_bundle.py`: one Shamela book → `book_<id>.sqlite.zst` with metadata, pages, FTS5 index.
3. Dart `normalizer.dart` passing the same test vectors.
4. Benchmark: in-book search latency on a mid-range Android device across a large book (e.g., a multi-volume tafsīr).