"""Acceptance tests for SPEC-003 (library catalog builder)."""

from __future__ import annotations

import json
import sqlite3
from pathlib import Path

import jsonschema
import pytest
import zstandard as zstd

from ishamela_data.normalizer import normalize

FIXTURES = Path(__file__).parent / "fixtures" / "catalog"
SIDECARS = FIXTURES / "sidecars"
META = FIXTURES / "meta"
MIXED = FIXTURES / "mixed_sidecars"
SCHEMA_PATH = Path(__file__).resolve().parents[1] / "schemas" / "catalog.schema.json"

GENERATED_AT = "2026-09-17T00:00:00Z"
CATALOG_VERSION = 3
BASE_URL = "https://huggingface.co/datasets/ishamela/bundles/resolve/main/books/"


def _build(out: Path, *, sidecars: Path = SIDECARS, keep_sqlite: bool = False):
    from ishamela_data.build_catalog import build_catalog_from_paths

    return build_catalog_from_paths(
        sidecars_dir=sidecars,
        out_dir=out,
        catalog_version=CATALOG_VERSION,
        generated_at=GENERATED_AT,
        base_url=BASE_URL,
        book_metadata_path=META / "book_metadata.parquet",
        authors_path=META / "authors.parquet",
        categories_path=META / "categories.parquet",
        source_revision="fixture-revision",
        keep_sqlite=keep_sqlite,
    )


def _open_catalog_sqlite(zst_path: Path, dest: Path) -> sqlite3.Connection:
    dctx = zstd.ZstdDecompressor()
    with zst_path.open("rb") as fin, dest.open("wb") as fout:
        dctx.copy_stream(fin, fout)
    conn = sqlite3.connect(dest)
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def test_catalog_fk_filename_and_fts(tmp_path: Path) -> None:
    result = _build(tmp_path / "out", keep_sqlite=True)
    assert result.zst_path.is_file()
    assert result.manifest_path.is_file()
    assert result.sqlite_path is not None and result.sqlite_path.is_file()

    conn = sqlite3.connect(result.sqlite_path)
    conn.execute("PRAGMA foreign_keys = ON")
    try:
        assert conn.execute("PRAGMA foreign_key_check").fetchall() == []
        books = conn.execute(
            "SELECT book_id, filename FROM books ORDER BY book_id"
        ).fetchall()
        assert books == [
            (900001, "book_900001.isb"),
            (900002, "book_900002.isb"),
            (900003, "book_900003.isb"),
        ]
        book_count = conn.execute("SELECT count(*) FROM books").fetchone()[0]
        fts_count = conn.execute("SELECT count(*) FROM books_fts").fetchone()[0]
        assert fts_count == book_count == 3
    finally:
        conn.close()


def test_title_search_with_diacritics(tmp_path: Path) -> None:
    result = _build(tmp_path / "out", keep_sqlite=True)
    assert result.sqlite_path is not None
    conn = sqlite3.connect(result.sqlite_path)
    try:
        q = normalize("الْكِتَابُ الْمُبِينُ")
        row = conn.execute(
            "SELECT rowid FROM books_fts WHERE books_fts MATCH ? ORDER BY rowid",
            (q,),
        ).fetchone()
        assert row is not None
        assert row[0] == 900001
    finally:
        conn.close()


def test_mixed_version_sidecars_rejected(tmp_path: Path) -> None:
    from ishamela_data.build_catalog import CatalogBuildError, build_catalog_from_paths

    with pytest.raises(CatalogBuildError, match="norm_version|schema_version|homogeneous"):
        build_catalog_from_paths(
            sidecars_dir=MIXED,
            out_dir=tmp_path / "out",
            catalog_version=CATALOG_VERSION,
            generated_at=GENERATED_AT,
            base_url=BASE_URL,
            book_metadata_path=META / "book_metadata.parquet",
            authors_path=META / "authors.parquet",
            categories_path=META / "categories.parquet",
            source_revision="fixture-revision",
        )


def test_catalog_json_matches_schema(tmp_path: Path) -> None:
    result = _build(tmp_path / "out")
    manifest = json.loads(result.manifest_path.read_text(encoding="utf-8"))
    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    jsonschema.validate(instance=manifest, schema=schema)
    assert manifest["catalog_version"] == CATALOG_VERSION
    assert manifest["generated_at"] == GENERATED_AT
    assert manifest["book_count"] == 3
    assert manifest["catalog_sqlite_zst"]["sha256"] == result.sha256
    assert manifest["catalog_sqlite_zst"]["bytes"] == result.zst_bytes


def test_determinism_identical_sha256(tmp_path: Path) -> None:
    a = _build(tmp_path / "a")
    b = _build(tmp_path / "b")
    assert a.sha256 == b.sha256
    assert a.zst_bytes == b.zst_bytes


def test_keep_sqlite(tmp_path: Path) -> None:
    out = tmp_path / "out"
    result = _build(out, keep_sqlite=True)
    assert result.sqlite_path == out / "catalog.sqlite"
    assert result.sqlite_path.is_file()
    # Also verify decompress path works
    conn = _open_catalog_sqlite(result.zst_path, tmp_path / "from_zst.sqlite")
    try:
        assert conn.execute("SELECT count(*) FROM books").fetchone()[0] == 3
    finally:
        conn.close()


def test_volume_count_zero_is_null(tmp_path: Path) -> None:
    result = _build(tmp_path / "out", keep_sqlite=True)
    assert result.sqlite_path is not None
    conn = sqlite3.connect(result.sqlite_path)
    try:
        row = conn.execute(
            "SELECT volume_count FROM books WHERE book_id = 900001"
        ).fetchone()
        assert row == (None,)
        row2 = conn.execute(
            "SELECT volume_count FROM books WHERE book_id = 900002"
        ).fetchone()
        assert row2 == (2,)
    finally:
        conn.close()
