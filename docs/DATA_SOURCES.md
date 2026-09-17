# Data Sources

Verified against the live Hugging Face repository. Do not invent field names —
if upstream changes, re-run the schema gate and update this file + SPEC-002.

## Primary corpus: `AuthenticIlm/Shamela4_Full_DB`

| Field | Value |
|---|---|
| Hub id | `AuthenticIlm/Shamela4_Full_DB` |
| Verified revision (sha) | `07554bee488a12955dd5231d08487ae7ce767d1e` |
| Verified on | 2026-09-17 |
| Books / pages (manifest) | 8,589 / ~7.6M |

### On-disk layout (hub root — **no** `stage0_raw/` prefix)

The dataset card mentions `stage0_raw/`; the published tree does **not** use that
prefix. Actual layout:

```
_meta/
  book_metadata.parquet
  categories.parquet
  authors.parquet
  …
01__العقيدة/
  1__الفواكه-العذاب-في-الرد-على-من-لم-يحكم-السنة-والكتاب/
    pages.jsonl
    toc.jsonl
    book_metadata.json
    manifest.json
02__…
…
40__…
```

Per-book directory name pattern: `{book_id}__{slug}/` under
`{category_sort:02d}__{category_name_ar}/`.

### `_meta/book_metadata.parquet` schema (8589 rows)

| Column | Type |
|---|---|
| `book_id` | Int64 |
| `shamela_id` | Int64 |
| `title_ar` | String |
| `book_type` | Int64 |
| `book_type_label` | String |
| `category_id` | Int64 |
| `category_name_ar` | String |
| `main_author_id` | Int64 |
| `main_author_name_ar` | String |
| `main_author_death_hijri` | Int64 |
| `main_author_death_hijri_text` | String |
| `authors_text` | String |
| `hijri_era` | Int64 |
| `printed` | Boolean |
| `is_hidden` | Boolean |
| `parent_id` | Int64 |
| `group_id` | Int64 |
| `version_major` | Int64 |
| `version_minor` | Int64 |
| `betaka_text` | String |
| `meta` | String |
| `volume_count_observed` | Int64 |
| `has_multi_part` | Boolean |
| `authors_json` | String |

No page-count column in the parquet; per-book `manifest.json` has `page_count`.

### `_meta/categories.parquet` schema (41 rows)

| Column | Type |
|---|---|
| `id` | Int64 |
| `name_ar` | String |
| `name_en` | Null (currently) |
| `sort_order` | Int64 |

### `_meta/authors.parquet` schema (3187 rows)

| Column | Type |
|---|---|
| `id` | Int64 |
| `shamela_id` | Int64 |
| `name_ar` | String |
| `death_hijri` | Int64 |
| `death_hijri_text` | String |
| `alpha_sort` | Int64 |
| `biography` | String |

### SPEC-003 catalog joins

Catalog builder (`ishamela-catalog`) consumes SPEC-002 `book_*.json` sidecars and
joins HF `_meta` for FK / volume fields:

| Catalog column | Source |
|---|---|
| `books.*` sizes / sha256 / title / page_count | sidecar |
| `books.filename` | derived `book_{id}.isb` |
| `books.category_id` | `book_metadata.category_id` |
| `books.author_id` | `book_metadata.main_author_id` |
| `books.volume_count` | `book_metadata.volume_count_observed` (`0` → SQL NULL) |
| `categories.id` / `name` / `position` | `categories.id` / `name_ar` / `sort_order` |
| `authors.id` / `name` / `death_year_hijri` | `authors.id` / `name_ar` / `death_hijri` |

### `pages.jsonl` object schema (one page per line)

| Field | Type | Notes |
|---|---|---|
| `page_id` | int | Upstream page id |
| `book_id` | int | FK |
| `shamela_page_id` | int | Original Shamela id |
| `part` | string \| null | Volume / juzʾ label |
| `page_num` | int \| null | **Print-edition** page number |
| `sequence_num` | int | Reading order (1-based) |
| `body` | string | Verbatim source text (may contain `\r`, minimal HTML spans) |
| `footnotes` | string \| null | Out of scope for SPEC-002 bundles |
| `hints` | string \| null | Out of scope for SPEC-002 bundles |
| `services_raw` | any \| null | Out of scope for SPEC-002 bundles |

### Mapping into SPEC-002 bundle tables

| Bundle column / meta key | Upstream source |
|---|---|
| `pages.id` | `sequence_num` |
| `pages.part` | `part` |
| `pages.page_number` | `page_num` |
| `pages.body` | `body` (verbatim) |
| `meta.title` | `title_ar` |
| `meta.author` | `main_author_name_ar` |
| `meta.category_id` | `category_id` |
| `meta.category_name` | `category_name_ar` |
| `meta.book_id` | `book_id` |

### ʿAqīdah sample book (acceptance)

| Field | Value |
|---|---|
| `book_id` | `1` |
| Path | `01__العقيدة/1__الفواكه-العذاب-في-الرد-على-من-لم-يحكم-السنة-والكتاب/` |
| Title | الفواكه العذاب في الرد على من لم يحكم السنة والكتاب |
| Author | حمد بن ناصر آل معمر |
| Category | العقيدة (`category_id=1`) |
| `page_count` (manifest) | 90 |

Note: CLI example `--book-id 43` in SPEC-002 is a generic id; book 43 lives under
`26__التراجم-والطبقات/`, not ʿAqīdah. Acceptance tests use book **1**.

## Other datasets (not used by SPEC-002)

| Dataset | Role | Status |
|---|---|---|
| `ieasybooks-org/shamela-waqfeya-library` | Scanned PDFs | Later milestone |
| `ieasybooks-org/waqfeya-library` | Scanned PDFs | Later milestone |
| `ieasybooks-org/prophet-mosque-library` | Scanned PDFs | Later milestone |
