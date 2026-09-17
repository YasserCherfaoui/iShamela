<div align="center">

# 📚 iShamela

**A modern, open-source, cross-platform library for the Islamic Sciences.**

*Search, read, and study thousands of classical Arabic texts — the Shamela corpus, the Waqfeya library, and more — in one beautiful app.*

[![License: MIT](https://img.shields.io/badge/Code%20License-MIT-blue.svg)](LICENSE)
[![Status: Pre-alpha](https://img.shields.io/badge/Status-pre--alpha-orange.svg)](#roadmap)
[![Data: Hugging Face](https://img.shields.io/badge/Data-Hugging%20Face-yellow.svg)](#data-sources)

</div>

---

## What is iShamela?

iShamela aims to bring the vast body of Islamic Sciences content available online into a single, modern reading and research experience — on mobile, desktop, and the web.

Today, students of knowledge juggle multiple tools: the desktop-only Shamela application, scattered PDF archives, and websites of varying quality. iShamela unifies them:

- **📖 Read** — a clean, distraction-free Arabic reader with proper typography, night mode, bookmarks, and reading progress.
- **🔍 Search** — fast full-text search across thousands of books, with Arabic-aware normalization (diacritics, hamza/alef variants, root-based lookup).
- **🗂 Browse** — navigate by discipline (ʿAqīdah, Tafsīr, Ḥadīth, Fiqh, Uṣūl, Sīrah, …), author, or era.
- **📄 Original editions** — access scanned PDFs of critical editions when the page image matters.
- **📴 Offline-first** — download the books you study; everything works without a connection.

## Data sources

All content is sourced from openly published datasets on Hugging Face. The app fetches data from these sources; this repository contains **code only**, no book content.

| Dataset | Type | Role in iShamela |
|---|---|---|
| [`AuthenticIlm/Shamela4_Full_DB`](https://huggingface.co/datasets/AuthenticIlm/Shamela4_Full_DB) | Structured text (8,589 books, 7.6M pages) | Core text engine: reading & search |
| [`ieasybooks-org/shamela-waqfeya-library`](https://huggingface.co/datasets/ieasybooks-org/shamela-waqfeya-library) | Scanned PDFs | Original-edition page images |
| [`ieasybooks-org/waqfeya-library`](https://huggingface.co/datasets/ieasybooks-org/waqfeya-library) | Scanned PDFs | Extended PDF library |
| [`ieasybooks-org/prophet-mosque-library`](https://huggingface.co/datasets/ieasybooks-org/prophet-mosque-library) | Scanned PDFs | Extended PDF library |

More sources will be added over time — the architecture treats data sources as pluggable providers.

## Architecture at a glance

```
┌─────────────────────────────────────────────┐
│                 Flutter app                 │
│   (Android · iOS · Windows · macOS · Web)   │
│  Reader · Search UI · Library · Downloads   │
└──────────────────┬──────────────────────────┘
                   │ downloads per-book bundles
┌──────────────────▼──────────────────────────┐
│         ishamela-data pipeline (CI)         │
│  HF datasets → clean → normalize → SQLite   │
│        bundles + metadata catalogs          │
└──────────────────┬──────────────────────────┘
                   │ reads from
┌──────────────────▼──────────────────────────┐
│         Hugging Face datasets (source)      │
└─────────────────────────────────────────────┘
```

Two pillars, deliberately separated:

1. **Text engine** — structured text from `Shamela4_Full_DB`, transformed into per-book SQLite bundles with FTS5 full-text search (see [ADR-001](docs/adr/001-search-strategy.md)).
2. **PDF library** — scanned editions streamed/downloaded from the ieasybooks datasets.

## Project structure

```
iShamela/
├── app/            # Flutter application
├── data/           # Data pipeline: HF datasets → app-ready bundles
├── docs/
│   ├── VISION.md   # Product vision & scope
│   ├── adr/        # Architecture Decision Records
│   └── ...
└── README.md
```

## Roadmap

- **M0 — Data foundation**: audit all four datasets; pipeline that produces one clean, searchable SQLite bundle from a Shamela book.
- **M1 — MVP reader**: Flutter app — browse catalog, download a book, read it, search inside it.
- **M2 — Corpus search**: search across all downloaded books; category/author browsing.
- **M3 — PDF library**: browse and read scanned editions from the ieasybooks datasets.
- **M4 — Study tools**: bookmarks, highlights, notes, cross-references, sharing.

See [docs/VISION.md](docs/VISION.md) for the full product vision.

## Content licensing

The **code** in this repository is MIT-licensed. The **book content** is *not* distributed with this repository: it remains on Hugging Face under the terms of each dataset. The classical texts are in the public domain; rights to critical editions belong to their editors (muhaqqiqīn) and publishers, and the Shamela4 dataset is published for research and personal use. iShamela respects these terms — see `docs/LICENSING.md` (forthcoming).

## Contributing

iShamela is at the very beginning. If you care about making the Islamic library accessible to everyone, you're welcome:

1. Read [docs/VISION.md](docs/VISION.md) to understand where we're going.
2. Check the open issues and the project board.
3. Open a discussion before large changes — architecture is settled through ADRs in `docs/adr/`.

### Duʿāʾ for contributors

To everyone who contributes to this project — code, data, docs, review, or duʿāʾ — may Allah accept it and count it among your ḥasanāt:

> **العربية**
>
> اللَّهُمَّ اجْزِ كُلَّ مَنْ سَاهَمَ فِي هَذَا الْمَشْرُوعِ خَيْرَ الْجَزَاءِ، وَاحْسُبْهُ فِي حَسَنَاتِهِ، وَاجْعَلْهُ مِمَّا يَنْفَعُهُ بَعْدَ مَوْتِهِ، وَبَارِكْ لَهُ فِي عِلْمِهِ وَعَمَلِهِ، وَتَقَبَّلْ مِنَّا وَمِنْهُمْ إِنَّكَ أَنْتَ السَّمِيعُ الْعَلِيمُ.
>
> **Transliteration**
>
> *Allāhumma ijzi kulla man sāhama fī hādhā al-mashrūʿi khayra al-jazāʾ, wa-ḥsubhu fī ḥasanātihi, wa-jʿalhu mimmā yanfaʿuhu baʿda mawtihi, wa-bārik lahu fī ʿilmihi wa-ʿamalih, wa-taqabbal minnā wa-minhum, innaka Anta as-Samīʿu al-ʿAlīm.*
>
> **Translation**
>
> *O Allah, reward everyone who contributed to this project with the best of rewards, count it among their good deeds (ḥasanāt), make it among what benefits them after death, bless them in their knowledge and their work, and accept from us and from them — indeed You are the All-Hearing, the All-Knowing.*

جزاكم الله خيرًا — *jazākumu Llāhu khayran* — may Allah reward you with good.

## Acknowledgements

- **al-Maktaba al-Shamela** ([shamela.ws](https://shamela.ws)) — the foundation of digital Islamic text libraries.
- **AuthenticIlm** — for the Shamela 4 full corpus extraction.
- **ieasybooks** — for the Waqfeya and Prophet's Mosque PDF libraries.
- The muhaqqiqīn and publishers whose editorial work these texts preserve.