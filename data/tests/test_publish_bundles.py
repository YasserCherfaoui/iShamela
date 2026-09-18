"""Acceptance tests for SPEC-007 publish dry-run."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

import pytest

from ishamela_data.build_catalog import build_catalog_from_paths

FIXTURES = Path(__file__).parent / "fixtures" / "catalog"
META = FIXTURES / "meta"
SCHEMA_PATH = Path(__file__).resolve().parents[1] / "schemas" / "catalog.schema.json"

GENERATED_AT = "2026-09-17T00:00:00Z"
BASE_URL = "https://huggingface.co/datasets/AuthenticIlm/Shamela4_Full_DB/resolve/main/books/"


def _write_book(sidecars: Path, books: Path, book_id: int, *, title: str, author: str) -> None:
    payload = f"fake-isb-{book_id}\n".encode()
    digest = hashlib.sha256(payload).hexdigest()
    books.mkdir(parents=True, exist_ok=True)
    (books / f"book_{book_id}.isb").write_bytes(payload)
    sidecar = {
        "book_id": book_id,
        "title": title,
        "author": author,
        "category": "العقيدة",
        "page_count": 10,
        "isb_bytes": len(payload),
        "sqlite_bytes": 4000,
        "sha256": digest,
        "schema_version": "1",
        "norm_version": "1.0.0",
    }
    sidecars.mkdir(parents=True, exist_ok=True)
    (sidecars / f"book_{book_id}.json").write_text(
        json.dumps(sidecar, ensure_ascii=False, sort_keys=True),
        encoding="utf-8",
    )


def _prepare_dist(tmp: Path) -> tuple[Path, Path]:
    sidecars = tmp / "sidecars"
    books = tmp / "books"
    _write_book(sidecars, books, 900001, title="الْكِتَابُ الْمُبِينُ", author="أحمد بن مثال")
    _write_book(sidecars, books, 900002, title="رسالة في التوحيد", author="محمد بن مثال")
    _write_book(sidecars, books, 900003, title="كتاب ثالث", author="أحمد بن مثال")
    catalog_dir = tmp / "catalog"
    build_catalog_from_paths(
        sidecars_dir=sidecars,
        out_dir=catalog_dir,
        catalog_version=7,
        generated_at=GENERATED_AT,
        base_url=BASE_URL,
        book_metadata_path=META / "book_metadata.parquet",
        authors_path=META / "authors.parquet",
        categories_path=META / "categories.parquet",
        source_revision="fixture-revision",
        keep_sqlite=False,
    )
    return catalog_dir, books


def test_publish_dry_run_plans_uploads(tmp_path: Path) -> None:
    from ishamela_data.publish_bundles import plan_publish

    catalog_dir, books_dir = _prepare_dist(tmp_path)
    plan = plan_publish(
        catalog_dir=catalog_dir,
        books_dir=books_dir,
        schema_path=SCHEMA_PATH,
    )
    repo_paths = {item.repo_path for item in plan}
    assert "catalog/catalog.json" in repo_paths
    assert "catalog/catalog.sqlite.zst" in repo_paths
    assert "books/book_900001.isb" in repo_paths
    assert "books/book_900002.isb" in repo_paths
    assert "books/book_900003.isb" in repo_paths
    assert len(plan) == 5


def test_publish_dry_run_cli_exits_zero(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    from ishamela_data.publish_cli import main

    catalog_dir, books_dir = _prepare_dist(tmp_path)
    code = main(
        [
            "--catalog-dir",
            str(catalog_dir),
            "--books-dir",
            str(books_dir),
            "--repo",
            "yassercherfaoui/ishamela-bundles",
            "--revision",
            "main",
            "--dry-run",
            "--schema",
            str(SCHEMA_PATH),
        ]
    )
    assert code == 0
    out = capsys.readouterr().out
    assert "catalog/catalog.json" in out
    assert "books/book_900001.isb" in out


def test_publish_refuses_missing_book(tmp_path: Path) -> None:
    from ishamela_data.publish_bundles import PublishError, plan_publish

    catalog_dir, books_dir = _prepare_dist(tmp_path)
    (books_dir / "book_900002.isb").unlink()
    with pytest.raises(PublishError, match="missing|900002"):
        plan_publish(
            catalog_dir=catalog_dir,
            books_dir=books_dir,
            schema_path=SCHEMA_PATH,
        )


def test_publish_refuses_sha256_mismatch(tmp_path: Path) -> None:
    from ishamela_data.publish_bundles import PublishError, plan_publish

    catalog_dir, books_dir = _prepare_dist(tmp_path)
    (books_dir / "book_900001.isb").write_bytes(b"tampered")
    with pytest.raises(PublishError, match="sha256"):
        plan_publish(
            catalog_dir=catalog_dir,
            books_dir=books_dir,
            schema_path=SCHEMA_PATH,
        )


def test_publish_refuses_invalid_manifest(tmp_path: Path) -> None:
    from ishamela_data.publish_bundles import PublishError, plan_publish

    catalog_dir, books_dir = _prepare_dist(tmp_path)
    (catalog_dir / "catalog.json").write_text("{}", encoding="utf-8")
    with pytest.raises(PublishError, match="schema|manifest|catalog.json"):
        plan_publish(
            catalog_dir=catalog_dir,
            books_dir=books_dir,
            schema_path=SCHEMA_PATH,
        )
