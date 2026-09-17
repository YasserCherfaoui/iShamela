# iShamela — Product Vision

**Status:** Living document · **Owner:** Project maintainers · **Last updated:** 2026-09-17

## 1. The problem

The Islamic Sciences have one of the richest textual traditions in human history, and much of it is already digitized. Yet the experience of *using* that digital library is fragmented and dated:

- **al-Maktaba al-Shamela** is the reference tool, but it is Windows-desktop-centric, with an interface designed two decades ago and no first-class mobile or web experience.
- **Scanned critical editions** (Waqfeya, Prophet's Mosque library, and others) live in scattered archives with poor discoverability and no connection to the searchable text corpus.
- **Existing mobile apps** are mostly closed-source, ad-laden, cover a fraction of the corpus, or handle Arabic search poorly (no diacritic normalization, no variant matching).

A student researching a single fiqh question today may open a desktop app, two websites, and a PDF folder — with no way to move between the searchable text of a book and its printed critical edition.

## 2. The vision

**One open-source app that brings the online Islamic library to every reader, on every device.**

iShamela is:

- **Comprehensive** — the full Shamela corpus (8,589 books, 7.6M pages) as searchable text, plus scanned original editions, with an architecture that welcomes additional sources over time. The four launch datasets are a starting point, not a ceiling.
- **Modern** — the reading and search experience people expect in 2026: fast, beautiful Arabic typography, dark mode, sync-ready, cross-platform from a single codebase.
- **Open** — MIT-licensed code, public roadmap, decisions recorded as ADRs, community-driven. Anyone can audit how texts are processed and displayed.
- **Respectful of the tradition** — texts are presented faithfully, sources and editions are always attributed, and the rights of editors and publishers are honored (content stays on its source platforms; the app is a reader, not a redistributor).
- **Offline-first** — knowledge should not require bandwidth. Downloaded books are fully readable and searchable with no connection.

## 3. Who it's for

| Persona | Needs |
|---|---|
| **Student of knowledge** (ṭālib al-ʿilm) | Read assigned texts on phone/tablet; search within a book; bookmarks and notes. |
| **Researcher / graduate student** | Corpus-wide search; cite by book/volume/page matching the printed edition; open the scanned edition to verify. |
| **Teacher / imam** | Quickly locate a passage or hadith during preparation; share references. |
| **General reader** | Browse by topic; readable typography; guidance through the library's structure. |

## 4. Scope

### In scope (MVP → v1)

1. **Library catalog** — browse the Shamela corpus by category, author, and title; rich metadata (edition, publisher, muḥaqqiq, page-print correspondence).
2. **Reader** — per-page Arabic text rendering faithful to the source DB, with print-edition page numbers, footnotes, adjustable typography, night mode.
3. **Search** — Arabic-aware full-text search: within a book (MVP), across downloaded books (v1). Normalization of diacritics, hamza/alef/ya/ta-marbuta variants.
4. **Downloads** — per-book bundles fetched on demand; storage management.
5. **PDF library** — browse and open scanned editions from the ieasybooks datasets (post-MVP milestone).

### Out of scope (for now)

- User accounts, cloud sync, and social features.
- AI features (semantic search, summarization, Q&A) — attractive later, but the deterministic foundation comes first.
- Translations of the texts; the corpus is Arabic. (UI localization — Arabic, English, French — *is* planned.)
- Hosting or redistributing book content ourselves; sources remain the systems of record.

## 5. Product principles

1. **Data before pixels.** Every feature stands on the data pipeline; the pipeline is a first-class deliverable with its own tests.
2. **Faithfulness over convenience.** Never silently alter a text. Normalization is for *search indexes*; the displayed text is the source text.
3. **The page is the citation.** Print-edition page correspondence is preserved everywhere — reading, search results, sharing.
4. **Offline is the default, online is the enhancement.**
5. **Small, verifiable releases.** One book working end-to-end beats a thousand books half-working.

## 6. Success criteria (v1)

- A user can install the app on Android, iOS, or desktop, download any Shamela book, and read it offline.
- In-book search returns correct results for queries with or without diacritics in < 100 ms on a mid-range phone.
- Every displayed page shows its print-edition reference.
- A contributor can regenerate any book bundle from the Hugging Face source with one documented command.

## 7. Non-goals as a project

- Competing with shamela.ws — we build *on* the corpus they made possible and send users to sources for anything we don't cover.
- Monetization. iShamela is and will remain free and open-source.