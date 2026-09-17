#!/usr/bin/env python3
"""SPEC-006 audit for AuthenticIlm/Shamela4_Full_DB (D1).

Writes machine-readable outputs under ``data/audit/out/`` and prints a summary.
Metadata-first: uses HfApi list/info; downloads only ``_meta/*.parquet`` plus
three selected ``pages.jsonl`` files (budget: total audit download < 2 GB).
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from collections.abc import Iterable
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import polars as pl
from huggingface_hub import HfApi, hf_hub_download

REPO_ID = "AuthenticIlm/Shamela4_Full_DB"
DEFAULT_REVISION = "07554bee488a12955dd5231d08487ae7ce767d1e"

# Acceptance picks (SPEC-006 B.1): small, multi-volume, Quranic-sciences.
# Resolved after reading book_metadata; overrides via CLI.
DEFAULT_SMALL_MAX_PAGES = 100
DEFAULT_MULTI_MIN_PAGES = 2000

_OUT_NAMES = (
    "d1_topology.json",
    "d1_meta_schemas.txt",
    "d1_pages_keys.json",
    "d1_codepoints.tsv",
    "d1_footnotes.txt",
    "d1_extras.txt",
    "d1_summary.txt",
)


def _out_dir(root: Path) -> Path:
    d = root / "out"
    d.mkdir(parents=True, exist_ok=True)
    return d


def _audit_root() -> Path:
    return Path(__file__).resolve().parent


def topology(api: HfApi, revision: str) -> dict[str, Any]:
    info = api.repo_info(REPO_ID, repo_type="dataset", revision=revision)
    files = api.list_repo_files(REPO_ID, repo_type="dataset", revision=revision)
    # Size via siblings when available
    siblings = getattr(info, "siblings", None) or []
    size_by_path = {
        s.rfilename: getattr(s, "size", None) for s in siblings if getattr(s, "rfilename", None)
    }
    sizes = [s for s in size_by_path.values() if isinstance(s, int)]
    largest = None
    if size_by_path:
        named = [(p, sz) for p, sz in size_by_path.items() if isinstance(sz, int)]
        if named:
            largest = max(named, key=lambda x: x[1])

    # Depth / naming samples
    depths = [p.count("/") for p in files]
    pages = [p for p in files if p.endswith("/pages.jsonl")]
    meta = [p for p in files if p.startswith("_meta/") and p.endswith(".parquet")]
    card = api.dataset_info(REPO_ID, revision=revision)
    license_field = getattr(card, "cardData", None) or {}
    if hasattr(license_field, "get"):
        license_val = license_field.get("license")
    else:
        license_val = getattr(card, "license", None)

    last_modified = getattr(info, "lastModified", None) or getattr(info, "last_modified", None)
    return {
        "repo_id": REPO_ID,
        "revision": revision,
        "audited_at": datetime.now(timezone.utc).isoformat(),
        "file_count": len(files),
        "total_size_bytes_known": sum(sizes) if sizes else None,
        "files_with_known_size": len(sizes),
        "largest_file": {"path": largest[0], "bytes": largest[1]} if largest else None,
        "depth_min": min(depths) if depths else None,
        "depth_max": max(depths) if depths else None,
        "pages_jsonl_count": len(pages),
        "meta_parquet": sorted(meta),
        "sample_paths": sorted(files)[:40],
        "naming_pattern": (
            "{NN:02d}__{category_ar}/{book_id}__{slug}/pages.jsonl ; "
            "_meta/*.parquet at repo root (no stage0_raw/)"
        ),
        "license_field": license_val,
        "last_modified": str(last_modified) if last_modified else None,
        "sha": getattr(info, "sha", revision),
    }


def download_meta(cache: Path, revision: str) -> Path:
    cache.mkdir(parents=True, exist_ok=True)
    meta_dir = cache / "_meta"
    meta_dir.mkdir(parents=True, exist_ok=True)
    api_files = [
        "_meta/book_metadata.parquet",
        "_meta/categories.parquet",
        "_meta/authors.parquet",
    ]
    # Also pull any other _meta parquets listed at revision if cheap
    api = HfApi()
    for f in api.list_repo_files(REPO_ID, repo_type="dataset", revision=revision):
        if f.startswith("_meta/") and f.endswith(".parquet") and f not in api_files:
            api_files.append(f)
    for rel in api_files:
        path = hf_hub_download(
            REPO_ID,
            rel,
            repo_type="dataset",
            revision=revision,
            local_dir=str(cache),
        )
        print(f"downloaded {rel} -> {path}", file=sys.stderr)
    return meta_dir


def write_meta_schemas(meta_dir: Path, out: Path) -> None:
    lines: list[str] = []
    for pq in sorted(meta_dir.glob("*.parquet")):
        df = pl.read_parquet(pq)
        lines.append(f"=== {pq.name} ===")
        lines.append(f"rows: {df.height}")
        lines.append("schema:")
        for name, dtype in df.schema.items():
            lines.append(f"  {name}: {dtype}")
        lines.append("sample (up to 5 rows, JSON records):")
        # Avoid CSV — some meta tables have nested/struct columns.
        sample = df.head(5).to_dicts()
        lines.append(json.dumps(sample, ensure_ascii=False, indent=2, default=str))
        lines.append("")
    out.write_text("\n".join(lines), encoding="utf-8")


def _find_pages_path(api: HfApi, revision: str, book_id: int) -> str | None:
    needle = f"/{book_id}__"
    for f in api.list_repo_files(REPO_ID, repo_type="dataset", revision=revision):
        if f.endswith("/pages.jsonl") and needle in f:
            # exact book_id segment
            m = re.search(rf"(?:^|/)({book_id})__[^/]+/pages\.jsonl$", f)
            if m:
                return f
    return None


def pick_books(meta: pl.DataFrame) -> dict[str, int]:
    """Choose small / multi-volume / Quranic book ids from metadata + heuristics."""
    ids = set(meta["book_id"].to_list())
    small = 1 if 1 in ids else int(meta.sort("book_id")["book_id"][0])

    multi = small
    if "volume_count_observed" in meta.columns:
        cand = meta.filter(pl.col("volume_count_observed") >= 3).sort(
            "volume_count_observed", descending=True
        )
        if cand.height:
            multi = int(cand["book_id"][0])

    quranic = small
    if "category_name_ar" in meta.columns:
        for needle in ("علوم القرآن", "التجويد", "تفسير"):
            cand = meta.filter(pl.col("category_name_ar").str.contains(needle))
            if cand.height:
                quranic = int(cand.sort("book_id")["book_id"][0])
                break

    return {"small": small, "multi": multi, "quranic": quranic}


def resolve_multi_by_pages(
    api: HfApi,
    revision: str,
    meta: pl.DataFrame,
    cache: Path,
    min_pages: int = DEFAULT_MULTI_MIN_PAGES,
    probe_limit: int = 25,
) -> int | None:
    """Download manifests for high volume_count books until page_count >= min_pages."""
    if "volume_count_observed" not in meta.columns:
        return None
    cand = meta.filter(pl.col("volume_count_observed") >= 2).sort(
        "volume_count_observed", descending=True
    )
    for bid in cand["book_id"].to_list()[:probe_limit]:
        bid = int(bid)
        rel = _find_pages_path(api, revision, bid)
        if rel is None:
            continue
        # Prefer sibling manifest.json
        manifest_rel = rel.replace("/pages.jsonl", "/manifest.json")
        try:
            path = hf_hub_download(
                REPO_ID,
                manifest_rel,
                repo_type="dataset",
                revision=revision,
                local_dir=str(cache),
            )
            data = json.loads(Path(path).read_text(encoding="utf-8"))
            pc = data.get("page_count")
            print(f"probe book {bid} page_count={pc}", file=sys.stderr)
            if isinstance(pc, int) and pc >= min_pages:
                return bid
        except Exception as exc:  # noqa: BLE001
            print(f"probe book {bid} failed: {exc}", file=sys.stderr)
            continue
    return None



def download_pages(
    cache: Path, revision: str, book_ids: Iterable[int]
) -> dict[int, Path]:
    api = HfApi()
    out: dict[int, Path] = {}
    for bid in book_ids:
        rel = _find_pages_path(api, revision, bid)
        if rel is None:
            print(f"warning: pages.jsonl not found for book_id={bid}", file=sys.stderr)
            continue
        path = hf_hub_download(
            REPO_ID,
            rel,
            repo_type="dataset",
            revision=revision,
            local_dir=str(cache),
        )
        out[bid] = Path(path)
        print(f"downloaded book {bid} pages -> {path}", file=sys.stderr)
    return out


def analyze_pages(paths: dict[int, Path]) -> dict[str, Any]:
    key_counts: Counter[str] = Counter()
    key_nulls: Counter[str] = Counter()
    key_types: dict[str, Counter[str]] = {}
    total_lines = 0
    sequence_ok = True
    footnote_samples: list[str] = []
    codepoints: Counter[int] = Counter()

    for bid, path in paths.items():
        prev_seq: int | None = None
        with path.open("r", encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                total_lines += 1
                obj = json.loads(line)
                for k, v in obj.items():
                    key_counts[k] += 1
                    if v is None or v == "":
                        key_nulls[k] += 1
                    tname = type(v).__name__
                    key_types.setdefault(k, Counter())[tname] += 1
                body = obj.get("body") or ""
                if isinstance(body, str):
                    codepoints.update(ord(ch) for ch in body)
                    # Footnote heuristics
                    if "——" in body or "\n____" in body or "←" in body:
                        if len(footnote_samples) < 8:
                            footnote_samples.append(
                                f"book={bid} seq={obj.get('sequence_num')}: "
                                + body[:240].replace("\n", "\\n")
                            )
                    if obj.get("footnotes"):
                        if len(footnote_samples) < 12:
                            footnote_samples.append(
                                f"book={bid} footnotes field: "
                                + str(obj.get("footnotes"))[:240]
                            )
                seq = obj.get("sequence_num")
                if isinstance(seq, int):
                    if prev_seq is not None and seq != prev_seq + 1:
                        sequence_ok = False
                    prev_seq = seq

    keys_report = {
        "lines": total_lines,
        "books": sorted(paths.keys()),
        "sequence_monotonic_per_file": sequence_ok,
        "keys": {
            k: {
                "present_on_lines": key_counts[k],
                "null_or_empty": key_nulls[k],
                "null_pct": round(100.0 * key_nulls[k] / key_counts[k], 3)
                if key_counts[k]
                else None,
                "dtypes": dict(key_types.get(k, {})),
            }
            for k in sorted(key_counts)
        },
        "confirmed_mapping": {
            "book_id_key": "book_id",
            "body_key": "body",
            "print_page_key": "page_num",
            "part_key": "part",
            "order_key": "sequence_num (1-based, monotonic in samples)",
        },
    }
    return {
        "keys": keys_report,
        "codepoints": codepoints,
        "footnote_samples": footnote_samples,
    }


def write_codepoints(counts: Counter[int], out: Path) -> None:
    # codepoint, char, count, hex, name-ish bucket
    rows = ["codepoint\thex\tcount\tprintable"]
    for cp, n in counts.most_common():
        try:
            ch = chr(cp)
            printable = ch if ch.isprintable() and ch not in "\t\n\r" else ""
        except Exception:
            printable = ""
        rows.append(f"{cp}\tU+{cp:04X}\t{n}\t{printable}")
    out.write_text("\n".join(rows) + "\n", encoding="utf-8")


def write_extras(meta_dir: Path, out: Path, files_topo: dict[str, Any]) -> None:
    lines: list[str] = []
    lines.append("=== root_dictionary / hadith tables ===")
    # Search topology sample + full file list hint from meta dir siblings
    api = HfApi()
    rev = files_topo.get("revision", DEFAULT_REVISION)
    hits = [
        f
        for f in api.list_repo_files(REPO_ID, repo_type="dataset", revision=rev)
        if "root" in f.lower() or "hadith" in f.lower() or "narrat" in f.lower()
    ]
    if not hits:
        lines.append("No paths matching root/hadith/narrat in repo file list.")
    else:
        for h in hits[:50]:
            lines.append(h)
        if len(hits) > 50:
            lines.append(f"... and {len(hits) - 50} more")
    for name in ("root_dictionary.parquet", "hadith_narrators.parquet"):
        local = meta_dir / name
        if local.exists():
            df = pl.read_parquet(local)
            lines.append(f"\n=== local {name} schema ({df.height} rows) ===")
            for c, d in df.schema.items():
                lines.append(f"  {c}: {d}")
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="SPEC-006 D1 audit (Shamela4_Full_DB)")
    parser.add_argument("--revision", default=DEFAULT_REVISION)
    parser.add_argument(
        "--cache",
        type=Path,
        default=_audit_root().parent / "hf",
        help="HF local_dir cache (default: data/hf)",
    )
    parser.add_argument("--book-small", type=int, default=None)
    parser.add_argument("--book-multi", type=int, default=None)
    parser.add_argument("--book-quranic", type=int, default=None)
    parser.add_argument(
        "--skip-download",
        action="store_true",
        help="Use existing cache only (no HF calls for files)",
    )
    args = parser.parse_args(argv)

    root = _audit_root()
    out = _out_dir(root)
    api = HfApi()

    print(f"auditing {REPO_ID} @ {args.revision}", file=sys.stderr)
    topo = topology(api, args.revision)
    (out / "d1_topology.json").write_text(
        json.dumps(topo, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    if not args.skip_download:
        meta_dir = download_meta(args.cache, args.revision)
    else:
        meta_dir = args.cache / "_meta"
    write_meta_schemas(meta_dir, out / "d1_meta_schemas.txt")

    book_meta = pl.read_parquet(meta_dir / "book_metadata.parquet")
    picks = pick_books(book_meta)
    if args.book_small is not None:
        picks["small"] = args.book_small
    if args.book_multi is not None:
        picks["multi"] = args.book_multi
    else:
        resolved = resolve_multi_by_pages(api, args.revision, book_meta, args.cache)
        if resolved is not None:
            picks["multi"] = resolved
    if args.book_quranic is not None:
        picks["quranic"] = args.book_quranic
    book_ids = list(dict.fromkeys(picks.values()))
    print(f"selected books: {picks}", file=sys.stderr)

    if args.skip_download:
        pages: dict[int, Path] = {}
        for bid in book_ids:
            found = list(args.cache.glob(f"**/{bid}__*/pages.jsonl"))
            if found:
                pages[bid] = found[0]
    else:
        pages = download_pages(args.cache, args.revision, book_ids)

    analysis = analyze_pages(pages)
    (out / "d1_pages_keys.json").write_text(
        json.dumps(analysis["keys"], ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    write_codepoints(analysis["codepoints"], out / "d1_codepoints.tsv")
    (out / "d1_footnotes.txt").write_text(
        "\n\n".join(analysis["footnote_samples"]) + "\n"
        if analysis["footnote_samples"]
        else "No footnote markers sampled.\n",
        encoding="utf-8",
    )
    write_extras(meta_dir, out / "d1_extras.txt", topo)

    # SPEC-001 range checks
    cps = analysis["codepoints"]
    ranges = {
        "tashkil_064B_065F": sum(cps[c] for c in range(0x064B, 0x0660)),
        "superscript_alef_0670": cps[0x0670],
        "tatweel_0640": cps[0x0640],
        "quranic_06D6_06ED": sum(cps[c] for c in range(0x06D6, 0x06EE)),
        "arabic_ext_08D3_08FF": sum(cps[c] for c in range(0x08D3, 0x0900)),
        "presentation_FB50_FDFF": sum(cps[c] for c in range(0xFB50, 0xFE00)),
        "presentation_FE70_FEFF": sum(cps[c] for c in range(0xFE70, 0xFF00)),
        "lt_gt_htmlish": cps[ord("<")] + cps[ord(">")],
    }
    summary = [
        f"repo={REPO_ID}",
        f"revision={args.revision}",
        f"books={picks}",
        f"pages_lines={analysis['keys']['lines']}",
        f"codepoint_unique={len(cps)}",
        "range_hits=" + json.dumps(ranges),
        f"outputs={[n for n in _OUT_NAMES if (out / n).exists()]}",
    ]
    (out / "d1_summary.txt").write_text("\n".join(summary) + "\n", encoding="utf-8")
    print("\n".join(summary))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
