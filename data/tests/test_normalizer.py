"""Acceptance tests for SPEC-001 (Arabic search normalizer)."""

from __future__ import annotations

import json
import time
from pathlib import Path

from ishamela_data.normalizer import NORM_VERSION, normalize

VECTORS_PATH = (
    Path(__file__).resolve().parents[2] / "shared" / "norm_test_vectors.jsonl"
)


def _load_vectors() -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    with VECTORS_PATH.open(encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            rows.append(json.loads(line))
    return rows


def test_golden_file_has_at_least_40_vectors() -> None:
    assert len(_load_vectors()) >= 40


def test_norm_version() -> None:
    assert NORM_VERSION == "1.0.0"


def test_all_vectors() -> None:
    failures: list[str] = []
    for i, row in enumerate(_load_vectors(), start=1):
        got = normalize(row["in"])
        if got != row["out"]:
            failures.append(
                f"#{i} {row['note']!r}: {got!r} != {row['out']!r}"
            )
    assert not failures, "\n".join(failures)


def test_idempotence_on_all_vectors() -> None:
    failures: list[str] = []
    for i, row in enumerate(_load_vectors(), start=1):
        once = normalize(row["in"])
        twice = normalize(once)
        if once != twice:
            failures.append(f"#{i} {row['note']!r}: {once!r} != {twice!r}")
    assert not failures, "\n".join(failures)


def test_normalize_3000_word_page_under_5ms() -> None:
    page = ("الْحَمْدُ " * 3000).strip()
    assert len(page.split()) == 3000
    normalize(page)  # warmup
    best = float("inf")
    for _ in range(20):
        start = time.perf_counter()
        normalize(page)
        best = min(best, time.perf_counter() - start)
    assert best < 0.005, f"normalize(3000 words) took {best * 1000:.2f} ms (limit 5 ms)"
