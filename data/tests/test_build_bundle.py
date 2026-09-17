"""Acceptance tests for SPEC-002 (book bundle builder)."""

from __future__ import annotations

import json
import os
import sqlite3
from pathlib import Path

import pytest

from ishamela_data.build_bundle import (
    SCHEMA_VERSION,
    BookMeta,
    BundleBuildError,
    build_bundle,
    build_bundle_from_paths,
    decompress_isb,
)
from ishamela_data.cli import main as cli_main
from ishamela_data.normalizer import NORM_VERSION, normalize

FIXTURES = Path(__file__).parent / "fixtures"
SAMPLE_PAGES = FIXTURES / "book_900001" / "pages.jsonl"
EMPTY_PAGES = FIXTURES / "book_empty" / "pages.jsonl"
EMPTY_NORM_PAGES = FIXTURES / "book_empty_norm" / "pages.jsonl"

SAMPLE_BOOK = BookMeta(
    book_id=900001,
    title="كتاب تجريبي في العقيدة",
    author="مؤلف تجريبي",
    category_id=1,
    category_name="العقيدة",
)

REQUIRED_META_KEYS = {
    "schema_version",
    "norm_version",
    "book_id",
    "title",
    "author",
    "category_id",
    "category_name",
    "source_dataset",
    "source_revision",
    "page_count",
    "built_by",
}


def _build(tmp_path: Path, **kwargs):
    return build_bundle_from_paths(
        book=SAMPLE_BOOK,
        pages_path=SAMPLE_PAGES,
        out_dir=tmp_path,
        source_revision="test-revision",
        source_dataset="test/fixture",
        **kwargs,
    )


def _open_isb(isb_path: Path, tmp_path: Path) -> sqlite3.Connection:
    sqlite_path = tmp_path / "opened.sqlite"
    decompress_isb(isb_path, sqlite_path)
    return sqlite3.connect(sqlite_path)


def test_build_produces_isb_with_all_meta_keys(tmp_path: Path) -> None:
    result = _build(tmp_path)
    assert result.isb_path.is_file()
    assert result.sidecar_path.is_file()

    conn = _open_isb(result.isb_path, tmp_path)
    meta = dict(conn.execute("SELECT key, value FROM meta").fetchall())
    conn.close()
    assert set(meta) == REQUIRED_META_KEYS
    assert meta["schema_version"] == SCHEMA_VERSION
    assert meta["norm_version"] == NORM_VERSION
    assert meta["book_id"] == "900001"
    assert meta["title"] == SAMPLE_BOOK.title
    assert meta["author"] == SAMPLE_BOOK.author
    assert meta["category_id"] == "1"
    assert meta["category_name"] == "العقيدة"
    assert meta["source_dataset"] == "test/fixture"
    assert meta["source_revision"] == "test-revision"
    assert meta["page_count"] == "3"
    assert meta["built_by"].startswith("ishamela-data/")


def test_page_count_matches_upstream(tmp_path: Path) -> None:
    upstream = sum(1 for line in SAMPLE_PAGES.read_text(encoding="utf-8").splitlines() if line.strip())
    result = _build(tmp_path)
    conn = _open_isb(result.isb_path, tmp_path)
    count = conn.execute("SELECT count(*) FROM pages").fetchone()[0]
    conn.close()
    assert count == upstream == 3
    assert result.page_count == upstream


def test_body_is_verbatim(tmp_path: Path) -> None:
    raw = json.loads(SAMPLE_PAGES.read_text(encoding="utf-8").splitlines()[0])
    result = _build(tmp_path)
    conn = _open_isb(result.isb_path, tmp_path)
    body = conn.execute("SELECT body FROM pages WHERE id = 1").fetchone()[0]
    conn.close()
    assert body == raw["body"]


def test_fts_match_with_full_diacritics(tmp_path: Path) -> None:
    result = _build(tmp_path)
    query = "الرَّحْمَٰنِ"  # vocalized; appears on page 1 after normalize
    conn = _open_isb(result.isb_path, tmp_path)
    rows = conn.execute(
        "SELECT rowid FROM pages_fts WHERE pages_fts MATCH ? ORDER BY rowid",
        (normalize(query),),
    ).fetchall()
    conn.close()
    assert [r[0] for r in rows] == [1]


def test_determinism_identical_sha256(tmp_path: Path) -> None:
    out_a = tmp_path / "a"
    out_b = tmp_path / "b"
    a = _build(out_a)
    b = _build(out_b)
    assert a.sha256 == b.sha256
    assert a.isb_path.read_bytes() == b.isb_path.read_bytes()


def test_keep_sqlite(tmp_path: Path) -> None:
    result = _build(tmp_path, keep_sqlite=True)
    assert result.sqlite_path is not None
    assert result.sqlite_path.is_file()
    assert result.sqlite_path.stat().st_size == result.sqlite_bytes


def test_sidecar_json_fields(tmp_path: Path) -> None:
    result = _build(tmp_path)
    data = json.loads(result.sidecar_path.read_text(encoding="utf-8"))
    assert data["book_id"] == 900001
    assert data["title"] == SAMPLE_BOOK.title
    assert data["author"] == SAMPLE_BOOK.author
    assert data["category"] == "العقيدة"
    assert data["page_count"] == 3
    assert data["sha256"] == result.sha256
    assert data["schema_version"] == SCHEMA_VERSION
    assert data["norm_version"] == NORM_VERSION
    assert data["isb_bytes"] == result.isb_bytes
    assert data["sqlite_bytes"] == result.sqlite_bytes


def test_empty_page_set_fails(tmp_path: Path) -> None:
    with pytest.raises(BundleBuildError, match="empty page set"):
        build_bundle_from_paths(
            book=SAMPLE_BOOK,
            pages_path=EMPTY_PAGES,
            out_dir=tmp_path,
            source_revision="test",
        )


def test_empty_index_fails(tmp_path: Path) -> None:
    book = BookMeta(
        book_id=900002,
        title="x",
        author="y",
        category_id=1,
        category_name="العقيدة",
    )
    with pytest.raises(BundleBuildError, match="empty index"):
        build_bundle_from_paths(
            book=book,
            pages_path=EMPTY_NORM_PAGES,
            out_dir=tmp_path,
            source_revision="test",
        )


def test_cli_missing_book_id_exits_nonzero(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    def boom(*_a, **_k):
        raise BundleBuildError("missing book id: 999999999")

    monkeypatch.setattr("ishamela_data.cli.build_bundle", boom)
    code = cli_main(
        ["--book-id", "999999999", "--out", str(tmp_path), "--hf-cache", str(tmp_path / "hf")]
    )
    assert code == 1


@pytest.mark.integration
def test_aqidah_sample_book_1_from_hf(tmp_path: Path) -> None:
    if os.environ.get("ISHAMELA_HF") != "1":
        pytest.skip("set ISHAMELA_HF=1 to run Hugging Face integration test")
    revision = "07554bee488a12955dd5231d08487ae7ce767d1e"
    result = build_bundle(
        1,
        tmp_path / "dist",
        hf_cache=tmp_path / "hf",
        revision=revision,
        keep_sqlite=True,
    )
    assert result.page_count == 90
    conn = _open_isb(result.isb_path, tmp_path)
    meta = dict(conn.execute("SELECT key, value FROM meta").fetchall())
    count = conn.execute("SELECT count(*) FROM pages").fetchone()[0]
    # Known phrase from page 1 of book 1 (vocalized query side).
    hits = conn.execute(
        "SELECT rowid FROM pages_fts WHERE pages_fts MATCH ? LIMIT 5",
        (normalize("الحمد لله رب العالمين"),),
    ).fetchall()
    conn.close()
    assert set(meta) == REQUIRED_META_KEYS
    assert count == 90
    assert meta["source_revision"] == revision
    assert hits  # at least one hit
