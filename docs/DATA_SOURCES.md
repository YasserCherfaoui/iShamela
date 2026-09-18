# Data Sources

Canonical audit of upstream Hugging Face datasets (SPEC-006).
Machine outputs: [`data/audit/out/`](../data/audit/out/). Re-run scripts from
[`data/audit/README.md`](../data/audit/README.md).

## Audited at revisions

| Dataset | Git revision | Audited |
|---|---|---|
| `AuthenticIlm/Shamela4_Full_DB` (D1) | `07554bee488a12955dd5231d08487ae7ce767d1e` | 2026-09-17 |
| `ieasybooks-org/shamela-waqfeya-library` (D2) | `9d351576c6f707058e2d0410978dd138700a275c` | 2026-09-17 |
| `ieasybooks-org/waqfeya-library` (D3) | `6baff87f74cd3c53a6f3495d25c55b706cb55af8` | 2026-09-17 |
| `ieasybooks-org/prophet-mosque-library` (D4) | `fc5372ff6258e20d51c4ddf0b4326695675ef12c` | 2026-09-17 |

---

## 1. AuthenticIlm/Shamela4_Full_DB

### Topology

- Hub id: `AuthenticIlm/Shamela4_Full_DB`
- File count (revision above): **34,373**
- Layout: **no** `stage0_raw/` prefix (dataset card may mention it; published tree does not)
- Pattern: `{NN:02d}__{category_ar}/{book_id}__{slug}/pages.jsonl` (+ `toc.jsonl`, `book_metadata.json`, `manifest.json`)
- `_meta/*.parquet` (+ matching `.jsonl` for some tables) at repo root
- License field on card: `mit`
- Raw: [`data/audit/out/d1_topology.json`](../data/audit/out/d1_topology.json)

### Verified schemas (tables incl. dtypes)

Full dump: [`data/audit/out/d1_meta_schemas.txt`](../data/audit/out/d1_meta_schemas.txt),
[`data/audit/out/d1_extras.txt`](../data/audit/out/d1_extras.txt).

| Parquet | Rows (approx) | Notes |
|---|---|---|
| `book_metadata.parquet` | 8,589 | Primary book index; **SPEC-003 catalog input** |
| `categories.parquet` | 41 | **SPEC-003 catalog input** |
| `authors.parquet` | 3,187 | **SPEC-003 catalog input** |
| `root_dictionary.parquet` | 1,952,803 | `token: String`, `roots: List(String)` — post-v1 (ADR-001 §5) |
| `narrators.parquet` | present | Hadith narrator metadata — not in catalog v1 |
| `hadith_xrefs.parquet` | present | Cross-refs — not in catalog v1 |
| `page_isnads.parquet` | present | not in catalog v1 |
| `quran_verses.parquet` | present | not in catalog v1 |
| `tafsir_xrefs.parquet` | present | not in catalog v1 |

Resolve base: `https://huggingface.co/datasets/AuthenticIlm/Shamela4_Full_DB/resolve/main/`
(files under `_meta/…`). Blob UI: `…/blob/main/_meta/categories.parquet` (etc.).

#### Catalog mapping (SPEC-003) — pipeline only

`ishamela-catalog` downloads these three parquets at **build** time (and indexes
Hub `pages.jsonl` paths into `books.source_pages_path`). The app ships / syncs
`catalog.sqlite.zst` and installs books by fetching `pages.jsonl` from Shamela4
at the pinned revision (SPEC-008) — it does **not** read `_meta` parquets on device.

| Hub path | → catalog.sqlite |
|---|---|
| `_meta/categories.parquet` (`id`, `name_ar`, `sort_order`) | `categories` |
| `_meta/authors.parquet` (`id`, `name_ar`, `death_hijri`) | `authors` |
| `_meta/book_metadata.parquet` (`book_id`, `category_id`, `main_author_id`, `volume_count_observed`) | FK / volume fields on `books` |

Page counts for browse come from parquet/manifests or sidecars. Per-book
`{NN}__…/{id}__…/pages.jsonl` is the on-device install source (SPEC-008).

#### `book_metadata.parquet` columns

`book_id`, `shamela_id`, `title_ar`, `book_type`, `book_type_label`, `category_id`,
`category_name_ar`, `main_author_id`, `main_author_name_ar`, `main_author_death_hijri`,
`main_author_death_hijri_text`, `authors_text`, `hijri_era`, `printed`, `is_hidden`,
`parent_id`, `group_id`, `version_major`, `version_minor`, `betaka_text`, `meta`,
`volume_count_observed`, `has_multi_part`, `authors_json`.

No page-count column in parquet; per-book `manifest.json` has `page_count`.

#### `pages.jsonl` keys (enumerated across audit books)

Audit books: **1** (small, 90 pages), **6551** (multi, 65,431 pages — مجلة الرسالة),
**6** (Quranic sciences category). Combined lines: **66,500**.
Raw: [`data/audit/out/d1_pages_keys.json`](../data/audit/out/d1_pages_keys.json).

| Key | Role |
|---|---|
| `page_id` | Upstream page id |
| `book_id` | FK |
| `shamela_page_id` | Original Shamela id |
| `part` | Volume / juzʾ label (nullable) |
| `page_num` | **Print-edition** page number (nullable) |
| `sequence_num` | Reading order (1-based; monotonic in samples) |
| `body` | Verbatim source text |
| `footnotes` | Separate footnote field (often present) |
| `hints` | Nullable |
| `services_raw` | Nullable |

Confirmed mapping for SPEC-002: `sequence_num`→`pages.id`, `part`→`pages.part`,
`page_num`→`pages.page_number`, `body`→`pages.body`.

### Text characteristics

Census: [`data/audit/out/d1_codepoints.tsv`](../data/audit/out/d1_codepoints.tsv)
(unique codepoints in the three audit books: 137).

Range hits on those books (see `d1_summary.txt`):

| Range / mark | Count in audit sample |
|---|---|
| Tashkīl U+064B–U+065F | 889,682 |
| Superscript alef U+0670 | 0 |
| Tatweel U+0640 | 5,146 |
| Quranic annotation U+06D6–U+06ED | 0 |
| Arabic Extended-A U+08D3–U+08FF | 0 |
| Presentation forms U+FB50–U+FDFF | 14,737 |
| Presentation forms U+FE70–U+FEFF | 0 |
| `<` / `>` (HTML-ish) | 80,420 |

**Footnotes:** Primary convention is a dedicated `footnotes` field on the page
object, with markers such as `(¬١)`, `(*)`, editorial notes — not a separator
line inside `body`. Samples:
[`data/audit/out/d1_footnotes.txt`](../data/audit/out/d1_footnotes.txt).
SPEC-005 should render `body` verbatim and treat `footnotes` as a separate
stream (out of scope for SPEC-002 bundles today).

**Root / hadith tables:** Present as assumed (`root_dictionary`, `narrators`,
`hadith_xrefs`, etc.). Suitable for post-v1 root search (ADR-001 §5).

### Deviations from SPEC-002 assumptions

| Assumption | Finding | Follow-up |
|---|---|---|
| Hub path `stage0_raw/` | **False** on published tree | Already noted in SPEC-002; keep |
| `body` is plain Arabic only | **Often contains HTML-like spans** (`<`/`>` common) | Do **not** strip in pipeline (faithfulness); reader may style later |
| Presentation forms rare | **U+FB50–U+FDFF occur** in sample | SPEC-001 NFC-only is intentional (not NFKC); no change required unless product wants compatibility folding — open issue if QA complains |
| U+08D3–U+08FF / U+06D6–U+06ED always present | **Absent** in the three audit books | SPEC-001 strip ranges remain defensive; no amendment required from this census |
| Footnotes only in `body` | **`footnotes` field is primary** | SPEC-005; SPEC-002 correctly leaves footnotes out of FTS `body` |
| Multi-volume ≈ page count | `volume_count_observed` is **not** page count (e.g. book 6551: 1025 volumes / 65k pages) | Use `manifest.json` `page_count` for sizing |

SPEC-002 schema gate should cite this document rather than re-probing HF.

---

## 2. ieasybooks-org/shamela-waqfeya-library (D2)

### Topology

- Revision: `9d351576c6f707058e2d0410978dd138700a275c`
- Files: **43,278** · PDFs: **12,877**
- Known total size (siblings with size): **≈ 117 GB** (`total_size_bytes_known`)
- PDF size p50 ≈ **6.8 MB**, p95/max up to **≈ 269 MB**
- Layout: `pdf/<category>/<title> - <author> - <edition>/<file>.pdf` plus parallel `docx/` trees
- Raw: [`data/audit/out/d2_topology.json`](../data/audit/out/d2_topology.json)

### Index / metadata

No standalone CSV/JSON catalog among index candidates in this revision; titles
must be derived from **directory/file paths** (see overlap method).
[`data/audit/out/d2_index.json`](../data/audit/out/d2_index.json).

### Size stats / access pattern implications

Corpus is **tens of GB to ~0.1 TB** known; individual PDFs commonly multi‑MB,
tail to hundreds of MB. Future PDF milestone should prefer **on-demand
single-file download** (or page-range HTTP if the host supports it) — not
shipping whole libraries on device.

### Overlap with Shamela4 (D1×D2)

Method: sample 20 PDF paths; title = parent folder segment before ` - `;
SPEC-001 `normalize()`; exact lookup in D1 `title_ar` map.

- **Match rate: 0.35** (7 / 20) on exact normalized title
- Path-prefix heuristics raise recall further (~0.75 startswith-12 on the same sample) but are not exact
- Raw: [`data/audit/out/d2_d1_overlap.json`](../data/audit/out/d2_d1_overlap.json)

Feasible to offer “open scanned edition” for a **substantial minority** of
titles with exact match; production linking will need a stronger aligner
(edition/author disambiguation), not filename alone.

### Sample PDF

[`data/audit/out/d2_sample_pdf.json`](../data/audit/out/d2_sample_pdf.json):
valid `%PDF` header; text-layer heuristic **false** on the tiny sample sniffed
(stdlib only — not authoritative).

---

## 3. ieasybooks-org/waqfeya-library (D3)

### Topology

- Revision: `6baff87f74cd3c53a6f3495d25c55b706cb55af8`
- Files: **69,380** · PDFs: **22,443**
- Known total size: **≈ 218 GB**
- PDF p50 ≈ **6.7 MB**, max ≈ **558 MB**
- Paths encode category + long Arabic titles (often with Dewey-like prefixes)
- Raw: [`data/audit/out/d3_topology.json`](../data/audit/out/d3_topology.json)

### Index / metadata

Same finding as D2: no compact catalog file loaded; path-derived titles.
[`data/audit/out/d3_index.json`](../data/audit/out/d3_index.json).

### Size stats / access pattern implications

Larger than D2; same streaming/on-demand recommendation. Whole-library sync is
impractical for mobile.

### Sample PDF

See [`data/audit/out/d3_sample_pdf.json`](../data/audit/out/d3_sample_pdf.json).

---

## 4. ieasybooks-org/prophet-mosque-library (D4)

### Topology

- Revision: `fc5372ff6258e20d51c4ddf0b4326695675ef12c`
- **`files_metadata` returned 0 files** at audit time (empty siblings list)
- License field still reports `mit` on the dataset card
- Raw: [`data/audit/out/d4_topology.json`](../data/audit/out/d4_topology.json)

### Index / metadata / size / sample

Not available until the hub publishes file listing for this revision. Treat as
**blocked / empty** for planning until re-audited.

---

## 5. License declarations (verbatim quotes + links)

Hub `license` field values collected by audit (card YAML `license:`):

| Dataset | `license` field | Hub |
|---|---|---|
| `AuthenticIlm/Shamela4_Full_DB` | `mit` | https://huggingface.co/datasets/AuthenticIlm/Shamela4_Full_DB |
| `ieasybooks-org/shamela-waqfeya-library` | `mit` | https://huggingface.co/datasets/ieasybooks-org/shamela-waqfeya-library |
| `ieasybooks-org/waqfeya-library` | `mit` | https://huggingface.co/datasets/ieasybooks-org/waqfeya-library |
| `ieasybooks-org/prophet-mosque-library` | `mit` | https://huggingface.co/datasets/ieasybooks-org/prophet-mosque-library |

Raw JSON: [`data/audit/out/license_fields.json`](../data/audit/out/license_fields.json).

Interpretation / redistribution policy belongs in `docs/LICENSING.md` (not this
audit). Card `cardData` keys were empty in API responses at audit time; confirm
on the web UI if more terms appear in README prose.

---

## 6. Open questions

1. **D4 empty listing** — temporary hub glitch, private files, or truly empty
   revision? Re-run `audit_pdfs.py` when the card shows files.
2. **HTML in `body`** — how much should the reader sanitize vs display raw?
   (Product decision for SPEC-005; do not mutate stored `body`.)
3. **D1×D2 linking** — invest in a dedicated aligner (author + normalized title
   + edition) before promising “open scan of this page.”
4. **Presentation forms (U+FB50+)** — monitor search misses; SPEC-001 currently
   leaves them unchanged (NFC only).
5. **Download budget** — this audit stayed under **2 GB** (~200 MB D1 pages/meta
   + small PDF samples). Full PDF libraries are 100–200+ GB and must not be
   mirrored in-repo.
