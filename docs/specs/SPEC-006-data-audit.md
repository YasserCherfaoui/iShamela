# SPEC-006 — Data Audit & DATA_SOURCES.md

**Status:** Implemented · **Depends on:** nothing (can run first, in parallel with SPEC-001) · **Deliverables:** `docs/DATA_SOURCES.md` (filled), `data/audit/` scripts + raw outputs

## Purpose

Every downstream spec (002, 003, and the future PDF milestone) rests on assumptions about the four upstream Hugging Face datasets. This spec turns those assumptions into verified facts, recorded in one canonical document. It is deliberately cheap: scripts + a report, no product code.

## Datasets in scope

| # | Dataset | Assumed nature |
|---|---|---|
| D1 | `AuthenticIlm/Shamela4_Full_DB` | Structured text: per-book `pages.jsonl` + `_meta/*.parquet` |
| D2 | `ieasybooks-org/shamela-waqfeya-library` | Scanned PDFs of Shamela-overlapping books |
| D3 | `ieasybooks-org/waqfeya-library` | Scanned PDFs, broader Waqfeya archive |
| D4 | `ieasybooks-org/prophet-mosque-library` | Scanned PDFs, Prophet's Mosque library |

## Audit tasks

### A. Repo topology (all four)
For each dataset, record: file tree shape (depth, naming pattern), total size, file count, largest file, README/dataset-card claims, license field, last commit date, git revision audited (pin it — all findings reference this revision).
Method: `huggingface_hub.HfApi().list_repo_files` / `repo_info`; do NOT clone multi-TB repos. Metadata only, plus targeted small downloads.

### B. Shamela4 schema verification (D1 — feeds SPEC-002 directly)
1. Download `_meta/*.parquet` fully + `pages.jsonl` for THREE books: one small (< 100 pages), one multi-volume (> 2,000 pages), one Quranic-sciences book (heavy diacritics/ornaments).
2. For each parquet: print schema (column names, dtypes), row count, 5 sample rows → commit as `data/audit/out/d1_meta_schemas.txt`.
3. For pages.jsonl: enumerate ALL keys present across lines (not just the first line), % nullability per key, dtypes; confirm or correct: book id key, body key, print page number key, part/volume key, ordering guarantee.
4. Character census over the three books' text: full codepoint frequency table → `d1_codepoints.tsv`. This is the empirical input for SPEC-001's strip ranges (does U+08D3–U+08FF actually occur? tatweel frequency? any presentation forms U+FB50–U+FDFF/U+FE70–U+FEFF that argue for NFKC-style handling? any HTML entities or tags embedded in body?).
5. Footnote convention: how are footnotes encoded in `body` (separator line? markers?) — sample and document; SPEC-005 rendering depends on it.
6. Answer explicitly: are hadith narrator tables / root_dictionary present as assumed, with what schemas?

### C. PDF libraries survey (D2–D4)
1. Metadata/index files: does each repo ship a catalog (CSV/JSON) mapping files → book titles/authors? Record its schema. If none, note that titles must come from file paths.
2. Size reality: total TB per repo, size distribution of PDFs (p50/p95/max) — this decides whether the future PDF milestone streams page-ranges or downloads whole files.
3. Overlap check (D1×D2): for 20 randomly sampled D2 books, can they be matched to a Shamela4 book id (by title match after SPEC-001-style normalization)? Report match rate — this decides whether "open the scanned edition of this page" is feasible.
4. Download ONE small PDF per repo; record: scanned vs text layer (searchable?), typical resolution, bookmarks/outline presence.

### D. Licensing facts (all four)
Record verbatim: dataset-card license declarations and usage terms. No interpretation here — `docs/LICENSING.md` does that; this audit only collects the facts and links.

## `docs/DATA_SOURCES.md` — required structure

```markdown
# Data Sources
Audited at revisions: <table dataset → git revision → date>
## 1. AuthenticIlm/Shamela4_Full_DB
### Topology | ### Verified schemas (tables incl. dtypes) | ### Text characteristics (codepoint findings, footnote convention) | ### Deviations from SPEC-002 assumptions
## 2..4 <same per PDF dataset, with: Topology | Index/metadata | Size stats | Overlap with Shamela4 (D2 only) | Access pattern implications>
## 5. License declarations (verbatim quotes + links)
## 6. Open questions
```

Every SPEC-002 assumption confirmed or corrected MUST appear in §"Deviations" — with a linked follow-up PR to SPEC-002 when corrections are needed.

## Audit scripts

`data/audit/audit_d1.py`, `audit_pdfs.py` — same dependency allowlist as SPEC-002; each writes machine outputs to `data/audit/out/` (committed: they're small text/TSV) and prints a human summary. Re-runnable against a pinned `--revision`.

## Acceptance criteria

- [x] DATA_SOURCES.md filled per the structure above; no "TODO" left in §1–5.
- [x] All four repos pinned to explicit revisions; scripts re-run cleanly against those pins.
- [x] Codepoint census committed; SPEC-001 strip/fold ranges reviewed against it (no range amendment required from this sample; presentation-forms / HTML noted as open questions).
- [x] SPEC-002 schema gate can point to this document instead of re-verifying.
- [x] D2↔D1 overlap rate reported with method described.
- [x] Total download during audit < 2 GB (this is an audit, not a mirror).

## Out of scope

Fixing anything found; mirroring datasets; auditing future/additional datasets (repeat this spec's method when they're proposed).