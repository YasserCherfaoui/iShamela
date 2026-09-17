#!/usr/bin/env python3
"""SPEC-006 audit for PDF libraries D2–D4 (ieasybooks-org/*).

Uses ``repo_info(..., files_metadata=True)`` for file/size inventory (one call
per repo) instead of paginated recursive tree walks that trip HF rate limits.
Downloads at most one small PDF per repo. Overlap D1×D2: title-normalize match.
"""

from __future__ import annotations

import argparse
import csv
import json
import random
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import polars as pl
from huggingface_hub import HfApi, hf_hub_download

from ishamela_data.normalizer import normalize

D1 = "AuthenticIlm/Shamela4_Full_DB"
PDF_REPOS = {
    "d2": "ieasybooks-org/shamela-waqfeya-library",
    "d3": "ieasybooks-org/waqfeya-library",
    "d4": "ieasybooks-org/prophet-mosque-library",
}


def _audit_root() -> Path:
    return Path(__file__).resolve().parent


def _out_dir() -> Path:
    d = _audit_root() / "out"
    d.mkdir(parents=True, exist_ok=True)
    return d


def _siblings(api: HfApi, repo_id: str, revision: str | None) -> tuple[str, list[Any]]:
    info = api.repo_info(
        repo_id,
        repo_type="dataset",
        revision=revision,
        files_metadata=True,
    )
    sha = getattr(info, "sha", revision) or "main"
    siblings = list(getattr(info, "siblings", None) or [])
    return str(sha), siblings


def repo_topology(api: HfApi, repo_id: str, revision: str | None) -> dict[str, Any]:
    sha, siblings = _siblings(api, repo_id, revision)
    files = [s.rfilename for s in siblings if getattr(s, "rfilename", None)]
    size_by = {
        s.rfilename: getattr(s, "size", None)
        for s in siblings
        if getattr(s, "rfilename", None)
    }
    sizes = [sz for sz in size_by.values() if isinstance(sz, int)]
    pdfs = [f for f in files if f.lower().endswith(".pdf")]
    pdf_sizes = sorted(
        size_by[p] for p in pdfs if isinstance(size_by.get(p), int)
    )

    def pct(p: float) -> int | None:
        if not pdf_sizes:
            return None
        idx = min(len(pdf_sizes) - 1, int(p * (len(pdf_sizes) - 1)))
        return pdf_sizes[idx]

    index_candidates = [
        f
        for f in files
        if any(
            f.lower().endswith(ext)
            for ext in (".csv", ".json", ".jsonl", ".parquet", ".tsv")
        )
    ]
    card = api.dataset_info(repo_id, revision=sha)
    card_data = getattr(card, "cardData", None) or {}
    license_val = (
        card_data.get("license") if hasattr(card_data, "get") else getattr(card, "license", None)
    )
    largest = None
    named = [(p, sz) for p, sz in size_by.items() if isinstance(sz, int)]
    if named:
        largest = max(named, key=lambda x: x[1])

    depths = [p.count("/") for p in files] or [0]
    return {
        "repo_id": repo_id,
        "revision": sha,
        "audited_at": datetime.now(timezone.utc).isoformat(),
        "file_count": len(files),
        "pdf_count": len(pdfs),
        "total_size_bytes_known": sum(sizes) if sizes else None,
        "pdf_size_sum_known": sum(pdf_sizes) if pdf_sizes else None,
        "pdf_size_p50": pct(0.5),
        "pdf_size_p95": pct(0.95),
        "pdf_size_max": pdf_sizes[-1] if pdf_sizes else None,
        "largest_file": {"path": largest[0], "bytes": largest[1]} if largest else None,
        "depth_min": min(depths),
        "depth_max": max(depths),
        "index_candidate_files": index_candidates[:80],
        "sample_paths": sorted(files)[:40],
        "license_field": license_val,
        "last_modified": str(
            getattr(info := api.repo_info(repo_id, repo_type="dataset", revision=sha), "lastModified", None)
            or getattr(info, "last_modified", None)
        ),
        "_pdf_paths_sample_pool_size": len(pdfs),
    }


def download_smallest_pdf(
    siblings: list[Any],
    repo_id: str,
    revision: str,
    cache: Path,
) -> dict[str, Any] | None:
    pdfs = [
        (s.rfilename, getattr(s, "size", None))
        for s in siblings
        if str(getattr(s, "rfilename", "")).lower().endswith(".pdf")
        and isinstance(getattr(s, "size", None), int)
    ]
    if not pdfs:
        return {"skipped": True, "reason": "no PDF with known size in siblings"}
    smaller = [p for p in pdfs if p[1] <= 80_000_000]
    if not smaller:
        return {
            "skipped": True,
            "reason": "no PDF <= 80MB",
            "smallest_bytes": min(pdfs, key=lambda x: x[1])[1],
        }
    rel, size = min(smaller, key=lambda x: x[1])
    path = hf_hub_download(
        repo_id,
        rel,
        repo_type="dataset",
        revision=revision,
        local_dir=str(cache / repo_id.replace("/", "__")),
    )
    local = Path(path)
    head = local.read_bytes()[:4096]
    return {
        "path": rel,
        "local": str(local),
        "bytes": size or local.stat().st_size,
        "starts_with_pdf": head.startswith(b"%PDF"),
        "text_layer_heuristic": b"/Font" in head or b"/ToUnicode" in head,
        "note": (
            "Heuristic sniff only (no PDF parser on SPEC-006 allowlist)."
        ),
    }


def load_d1_titles(meta_parquet: Path) -> dict[str, int]:
    df = pl.read_parquet(meta_parquet)
    mapping: dict[str, int] = {}
    for row in df.select(["book_id", "title_ar"]).iter_rows(named=True):
        title = row["title_ar"] or ""
        key = normalize(title)
        if key and key not in mapping:
            mapping[key] = int(row["book_id"])
    return mapping


def d2_title_from_path(path: str) -> str:
    """Best-effort title from Waqfeya-style paths.

    Layout is typically ``pdf/<category>/<title> - <author> - <edition>/<file>.pdf``
    (also ``docx/...``). Prefer the parent directory's leading title segment.
    """
    parts = Path(path).parts
    if len(parts) >= 2:
        folder = parts[-2]
        title = folder.split(" - ")[0].strip()
        if title and not title.lower().endswith(".pdf"):
            return title
    name = Path(path).stem
    return name.replace("_", " ").replace("-", " ")


def overlap_d1_d2(
    pdf_paths: list[str],
    d1_titles: dict[str, int],
    sample_n: int = 20,
    seed: int = 42,
) -> dict[str, Any]:
    rng = random.Random(seed)
    sample = pdf_paths if len(pdf_paths) <= sample_n else rng.sample(pdf_paths, sample_n)
    matches = []
    misses = []
    for path in sample:
        raw_title = d2_title_from_path(path)
        key = normalize(raw_title)
        hit = d1_titles.get(key)
        row = {"path": path, "title_guess": raw_title, "norm": key, "book_id": hit}
        (matches if hit is not None else misses).append(row)
    return {
        "method": (
            "Sample N PDF paths from D2 siblings; title from filename stem; "
            "SPEC-001 normalize(); exact lookup in D1 title_ar map."
        ),
        "sample_n": len(sample),
        "match_count": len(matches),
        "match_rate": round(len(matches) / len(sample), 3) if sample else None,
        "matches": matches,
        "misses": misses[:20],
    }


def try_load_index(
    api: HfApi,
    repo_id: str,
    revision: str,
    candidates: list[str],
    cache: Path,
) -> dict[str, Any]:
    preferred = [
        f
        for f in candidates
        if any(k in f.lower() for k in ("meta", "catalog", "index", "books", "data"))
    ]
    pick = (preferred or candidates)[:3]
    reports = []
    for rel in pick:
        try:
            path = hf_hub_download(
                repo_id,
                rel,
                repo_type="dataset",
                revision=revision,
                local_dir=str(cache / repo_id.replace("/", "__")),
            )
            local = Path(path)
            entry: dict[str, Any] = {"path": rel, "bytes": local.stat().st_size}
            if rel.endswith(".parquet"):
                df = pl.read_parquet(local)
                entry["schema"] = {c: str(d) for c, d in df.schema.items()}
                entry["rows"] = df.height
            elif rel.endswith(".csv"):
                with local.open(newline="", encoding="utf-8", errors="replace") as fh:
                    reader = csv.reader(fh)
                    header = next(reader, None)
                    entry["header"] = header
                    entry["sample_rows"] = [next(reader, None) for _ in range(3)]
            elif rel.endswith(".json"):
                raw = local.read_text(encoding="utf-8", errors="replace")[:2_000_000]
                data = json.loads(raw)
                if isinstance(data, dict):
                    entry["top_keys"] = list(data.keys())[:40]
                elif isinstance(data, list) and data and isinstance(data[0], dict):
                    entry["list_len_approx"] = len(data)
                    entry["item_keys"] = list(data[0].keys())
            reports.append(entry)
        except Exception as exc:  # noqa: BLE001
            reports.append({"path": rel, "error": str(exc)})
    return {"candidates_considered": pick, "loaded": reports}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="SPEC-006 PDF libraries audit (D2–D4)")
    parser.add_argument("--d2-revision", default=None)
    parser.add_argument("--d3-revision", default=None)
    parser.add_argument("--d4-revision", default=None)
    parser.add_argument("--cache", type=Path, default=_audit_root() / "cache")
    parser.add_argument(
        "--d1-meta",
        type=Path,
        default=_audit_root().parent / "hf" / "_meta" / "book_metadata.parquet",
    )
    parser.add_argument("--overlap-n", type=int, default=20)
    parser.add_argument("--skip-pdf-download", action="store_true")
    parser.add_argument("--pause-s", type=float, default=3.0, help="Pause between repos")
    args = parser.parse_args(argv)

    out = _out_dir()
    api = HfApi()
    args.cache.mkdir(parents=True, exist_ok=True)

    pins: dict[str, str] = {}
    all_topo: dict[str, Any] = {}
    sibling_cache: dict[str, list[Any]] = {}

    for key, repo in PDF_REPOS.items():
        rev_arg = getattr(args, f"{key}_revision")
        print(f"topology {repo} revision={rev_arg or 'default'}", file=sys.stderr)
        sha, siblings = _siblings(api, repo, rev_arg)
        sibling_cache[key] = siblings
        # Build topology without a second heavy files_metadata call
        files = [s.rfilename for s in siblings if getattr(s, "rfilename", None)]
        size_by = {
            s.rfilename: getattr(s, "size", None)
            for s in siblings
            if getattr(s, "rfilename", None)
        }
        sizes = [sz for sz in size_by.values() if isinstance(sz, int)]
        pdfs = [f for f in files if f.lower().endswith(".pdf")]
        pdf_sizes = sorted(size_by[p] for p in pdfs if isinstance(size_by.get(p), int))

        def pct(p: float, arr: list[int] = pdf_sizes) -> int | None:
            if not arr:
                return None
            idx = min(len(arr) - 1, int(p * (len(arr) - 1)))
            return arr[idx]

        card = api.dataset_info(repo, revision=sha)
        card_data = getattr(card, "cardData", None) or {}
        license_val = card_data.get("license") if hasattr(card_data, "get") else None
        named = [(p, sz) for p, sz in size_by.items() if isinstance(sz, int)]
        largest = max(named, key=lambda x: x[1]) if named else None
        depths = [p.count("/") for p in files] or [0]
        index_candidates = [
            f
            for f in files
            if any(f.lower().endswith(ext) for ext in (".csv", ".json", ".jsonl", ".parquet", ".tsv"))
        ]
        topo = {
            "repo_id": repo,
            "revision": sha,
            "audited_at": datetime.now(timezone.utc).isoformat(),
            "file_count": len(files),
            "pdf_count": len(pdfs),
            "total_size_bytes_known": sum(sizes) if sizes else None,
            "pdf_size_sum_known": sum(pdf_sizes) if pdf_sizes else None,
            "pdf_size_p50": pct(0.5),
            "pdf_size_p95": pct(0.95),
            "pdf_size_max": pdf_sizes[-1] if pdf_sizes else None,
            "largest_file": {"path": largest[0], "bytes": largest[1]} if largest else None,
            "depth_min": min(depths),
            "depth_max": max(depths),
            "index_candidate_files": index_candidates[:80],
            "sample_paths": sorted(files)[:40],
            "license_field": license_val,
        }
        pins[key] = sha
        all_topo[key] = topo
        (out / f"{key}_topology.json").write_text(
            json.dumps(topo, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
        idx = try_load_index(api, repo, sha, index_candidates, args.cache)
        (out / f"{key}_index.json").write_text(
            json.dumps(idx, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
        if not args.skip_pdf_download:
            pdf_info = download_smallest_pdf(siblings, repo, sha, args.cache)
            (out / f"{key}_sample_pdf.json").write_text(
                json.dumps(pdf_info, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )
        time.sleep(args.pause_s)

    (out / "pdf_pins.json").write_text(json.dumps(pins, indent=2) + "\n", encoding="utf-8")

    d2_pdfs = [
        s.rfilename
        for s in sibling_cache.get("d2", [])
        if str(getattr(s, "rfilename", "")).lower().endswith(".pdf")
    ]
    if args.d1_meta.exists():
        titles = load_d1_titles(args.d1_meta)
        overlap = overlap_d1_d2(d2_pdfs, titles, sample_n=args.overlap_n)
    else:
        overlap = {"error": f"missing D1 meta at {args.d1_meta}"}
    (out / "d2_d1_overlap.json").write_text(
        json.dumps(overlap, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    licenses: dict[str, Any] = {}
    for key, repo in PDF_REPOS.items():
        card = api.dataset_info(repo, revision=pins[key])
        card_data = getattr(card, "cardData", None) or {}
        licenses[repo] = {
            "license": card_data.get("license") if hasattr(card_data, "get") else None,
            "card_data_keys": list(card_data.keys()) if hasattr(card_data, "keys") else [],
            "hub_url": f"https://huggingface.co/datasets/{repo}",
        }
    card = api.dataset_info(D1)
    card_data = getattr(card, "cardData", None) or {}
    licenses[D1] = {
        "license": card_data.get("license") if hasattr(card_data, "get") else None,
        "card_data_keys": list(card_data.keys()) if hasattr(card_data, "keys") else [],
        "hub_url": f"https://huggingface.co/datasets/{D1}",
    }
    (out / "license_fields.json").write_text(
        json.dumps(licenses, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    summary = {
        "pins": pins,
        "pdf_counts": {k: all_topo[k].get("pdf_count") for k in all_topo},
        "overlap_rate": overlap.get("match_rate"),
    }
    (out / "pdf_summary.txt").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
