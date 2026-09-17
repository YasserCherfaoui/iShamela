"""Smoke tests for SPEC-006 audit scripts (no HF by default)."""

from __future__ import annotations

import importlib.util
from pathlib import Path

import pytest

AUDIT = Path(__file__).resolve().parents[1] / "audit"


def _load(name: str):
    path = AUDIT / name
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec and spec.loader
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def test_audit_scripts_importable():
    d1 = _load("audit_d1.py")
    pdfs = _load("audit_pdfs.py")
    assert hasattr(d1, "main")
    assert hasattr(pdfs, "main")
    assert d1.DEFAULT_REVISION


def test_pick_books_prefers_book_one(tmp_path: Path):
    pl = pytest.importorskip("polars")
    d1 = _load("audit_d1.py")
    df = pl.DataFrame(
        {
            "book_id": [1, 99, 5],
            "volume_count_observed": [1, 10, 2],
            "category_name_ar": ["العقيدة", "التفسير", "علوم القرآن وأصول التفسير"],
        }
    )
    picks = d1.pick_books(df)
    assert picks["small"] == 1
    assert picks["multi"] == 99
    assert picks["quranic"] == 5


def test_d2_title_from_path():
    pdfs = _load("audit_pdfs.py")
    assert (
        pdfs.d2_title_from_path(
            "pdf/فقه مالكي/شرح التلقين - المازري - ط دار الغرب/03.pdf"
        )
        == "شرح التلقين"
    )
