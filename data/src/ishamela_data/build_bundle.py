"""Book bundle builder (SPEC-002).

Transforms one Shamela book (pages.jsonl + metadata) into a contentless-FTS5
SQLite database, then zstd-compresses it to ``book_<id>.isb``.
"""

from __future__ import annotations

import hashlib
import json
import re
import sqlite3
import tempfile
from collections.abc import Iterator
from dataclasses import dataclass
from importlib.metadata import version as pkg_version
from pathlib import Path
from typing import Any

import polars as pl
import zstandard as zstd
from huggingface_hub import HfApi, hf_hub_download

from ishamela_data.normalizer import NORM_VERSION, normalize

SCHEMA_VERSION = "3"
SOURCE_DATASET = "AuthenticIlm/Shamela4_Full_DB"
ZSTD_LEVEL = 19

_REQUIRED_META_KEYS = (
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
)

_BOOK_PAGES_RE = re.compile(r"(?:^|/)(\d+)__[^/]+/pages\.jsonl$")


class BundleBuildError(Exception):
    """Raised when a bundle cannot be built; message is safe to print to stderr."""


@dataclass(frozen=True)
class BookMeta:
    book_id: int
    title: str
    author: str
    category_id: int
    category_name: str


@dataclass(frozen=True)
class BundleResult:
    isb_path: Path
    sqlite_path: Path | None
    sidecar_path: Path
    sha256: str
    page_count: int
    isb_bytes: int
    sqlite_bytes: int


def tool_version() -> str:
    try:
        return pkg_version("ishamela-data")
    except Exception:
        return "0.0.0"


def _open_sqlite(path: Path) -> sqlite3.Connection:
    # page_size must be set before any tables exist.
    conn = sqlite3.connect(path)
    conn.execute("PRAGMA page_size = 4096")
    conn.execute("PRAGMA encoding = 'UTF-8'")
    conn.execute("PRAGMA journal_mode = OFF")
    conn.execute("PRAGMA synchronous = OFF")
    conn.execute("PRAGMA temp_store = MEMORY")
    return conn


def _create_schema(conn: sqlite3.Connection) -> None:
    conn.executescript(
        """
        CREATE TABLE meta (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        );

        CREATE TABLE pages (
          id INTEGER PRIMARY KEY,
          part TEXT,
          page_number INTEGER,
          body TEXT NOT NULL,
          source_page_id INTEGER,
          footnotes TEXT
        );

        CREATE VIRTUAL TABLE pages_fts USING fts5(
          body_norm,
          content='',
          tokenize='unicode61 remove_diacritics 0'
        );

        CREATE TABLE toc (
          id INTEGER PRIMARY KEY,
          parent_id INTEGER,
          title TEXT NOT NULL,
          page_id INTEGER NOT NULL,
          position INTEGER NOT NULL
        );
        """
    )


def _iter_pages(pages_path: Path) -> Iterator[dict[str, Any]]:
    with pages_path.open("r", encoding="utf-8") as fh:
        for line_no, line in enumerate(fh, start=1):
            line = line.strip()
            if not line:
                continue
            try:
                yield json.loads(line)
            except json.JSONDecodeError as exc:
                raise BundleBuildError(
                    f"invalid JSON in {pages_path} line {line_no}: {exc}"
                ) from exc


def _insert_pages(
    conn: sqlite3.Connection, pages_path: Path
) -> tuple[int, int, dict[int, int]]:
    """Insert pages and FTS rows.

    Returns ``(page_count, non_empty_norm_count, source_page_id → pages.id)``.
    """
    page_count = 0
    non_empty_norm = 0
    pages_rows: list[
        tuple[int, str | None, int | None, str, int | None, str | None]
    ] = []
    fts_rows: list[tuple[int, str]] = []
    source_to_id: dict[int, int] = {}

    # Prefer sequence_num; on collision allocate next free id (upstream can
    # repeat sequence_num — e.g. book 8428 — which would violate PRIMARY KEY).
    used_ids: set[int] = set()
    next_free_id = 1

    for obj in _iter_pages(pages_path):
        try:
            page_id = int(obj["sequence_num"])
        except (KeyError, TypeError, ValueError) as exc:
            raise BundleBuildError(
                f"page missing valid sequence_num in {pages_path}"
            ) from exc
        if page_id in used_ids:
            while next_free_id in used_ids:
                next_free_id += 1
            page_id = next_free_id
        used_ids.add(page_id)
        if page_id >= next_free_id:
            next_free_id = page_id + 1

        body = obj.get("body")
        if body is None:
            raise BundleBuildError(f"page {page_id} missing body in {pages_path}")
        if not isinstance(body, str):
            raise BundleBuildError(f"page {page_id} body is not a string")

        part = obj.get("part")
        if part is not None and not isinstance(part, str):
            part = str(part)

        page_num = obj.get("page_num")
        page_number: int | None
        if page_num is None:
            page_number = None
        else:
            try:
                page_number = int(page_num)
            except (TypeError, ValueError) as exc:
                raise BundleBuildError(
                    f"page {page_id} has invalid page_num={page_num!r}"
                ) from exc

        source_page_id: int | None
        raw_spid = obj.get("page_id")
        if raw_spid is None:
            source_page_id = None
        else:
            try:
                source_page_id = int(raw_spid)
            except (TypeError, ValueError) as exc:
                raise BundleBuildError(
                    f"page {page_id} has invalid page_id={raw_spid!r}"
                ) from exc
            source_to_id[source_page_id] = page_id

        fn_raw = obj.get("footnotes")
        footnotes: str | None
        if fn_raw is None:
            footnotes = None
        elif isinstance(fn_raw, str):
            footnotes = fn_raw
        else:
            footnotes = str(fn_raw)

        body_norm = normalize(body)
        pages_rows.append(
            (page_id, part, page_number, body, source_page_id, footnotes)
        )
        if body_norm:
            fts_rows.append((page_id, body_norm))
            non_empty_norm += 1
        page_count += 1

        if len(pages_rows) >= 500:
            conn.executemany(
                "INSERT INTO pages "
                "(id, part, page_number, body, source_page_id, footnotes) "
                "VALUES (?, ?, ?, ?, ?, ?)",
                pages_rows,
            )
            conn.executemany(
                "INSERT INTO pages_fts (rowid, body_norm) VALUES (?, ?)",
                fts_rows,
            )
            pages_rows.clear()
            fts_rows.clear()

    if pages_rows:
        conn.executemany(
            "INSERT INTO pages "
            "(id, part, page_number, body, source_page_id, footnotes) "
            "VALUES (?, ?, ?, ?, ?, ?)",
            pages_rows,
        )
        conn.executemany(
            "INSERT INTO pages_fts (rowid, body_norm) VALUES (?, ?)",
            fts_rows,
        )

    return page_count, non_empty_norm, source_to_id


def _insert_toc(
    conn: sqlite3.Connection,
    toc_path: Path,
    source_to_id: dict[int, int],
) -> int:
    """Insert TOC rows; skip entries whose upstream page_id cannot be resolved."""
    if not toc_path.is_file():
        return 0
    rows: list[tuple[int, int | None, str, int, int]] = []
    skipped = 0
    for obj in _iter_pages(toc_path):
        try:
            title_id = int(obj["title_id"])
            title = obj["title_text"]
            upstream_page = int(obj["page_id"])
        except (KeyError, TypeError, ValueError):
            skipped += 1
            continue
        if not isinstance(title, str):
            title = str(title)
        page_id = source_to_id.get(upstream_page)
        if page_id is None:
            skipped += 1
            continue
        parent_raw = obj.get("parent_id")
        parent_id = None if parent_raw is None else int(parent_raw)
        try:
            position = int(obj.get("shamela_title_id") or title_id)
        except (TypeError, ValueError):
            position = title_id
        rows.append((title_id, parent_id, title, page_id, position))
    if rows:
        conn.executemany(
            "INSERT INTO toc (id, parent_id, title, page_id, position) "
            "VALUES (?, ?, ?, ?, ?)",
            rows,
        )
    _ = skipped
    return len(rows)


def _write_meta(
    conn: sqlite3.Connection,
    *,
    book: BookMeta,
    page_count: int,
    source_revision: str,
    source_dataset: str,
) -> None:
    rows = {
        "schema_version": SCHEMA_VERSION,
        "norm_version": NORM_VERSION,
        "book_id": str(book.book_id),
        "title": book.title,
        "author": book.author,
        "category_id": str(book.category_id),
        "category_name": book.category_name,
        "source_dataset": source_dataset,
        "source_revision": source_revision,
        "page_count": str(page_count),
        "built_by": f"ishamela-data/{tool_version()}",
    }
    assert set(rows) == set(_REQUIRED_META_KEYS)
    conn.executemany(
        "INSERT INTO meta (key, value) VALUES (?, ?)",
        sorted(rows.items()),
    )


def _sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def _compress_zstd(src: Path, dst: Path) -> None:
    # Pledge size so the frame stores content size (helps clients that size
    # the output buffer from ZSTD_getFrameContentSize).
    cctx = zstd.ZstdCompressor(level=ZSTD_LEVEL, write_content_size=True)
    with src.open("rb") as fin, dst.open("wb") as fout:
        cctx.copy_stream(fin, fout, size=src.stat().st_size)


def build_bundle_from_paths(
    *,
    book: BookMeta,
    pages_path: Path,
    out_dir: Path,
    source_revision: str,
    source_dataset: str = SOURCE_DATASET,
    keep_sqlite: bool = False,
    toc_path: Path | None = None,
    betaka: str | None = None,
) -> BundleResult:
    """Build ``book_<id>.isb`` (+ sidecar) from local pages.jsonl + BookMeta."""
    if not pages_path.is_file():
        raise BundleBuildError(f"pages file not found: {pages_path}")

    out_dir.mkdir(parents=True, exist_ok=True)
    isb_path = out_dir / f"book_{book.book_id}.isb"
    sidecar_path = out_dir / f"book_{book.book_id}.json"
    kept_sqlite: Path | None = (
        out_dir / f"book_{book.book_id}.sqlite" if keep_sqlite else None
    )

    with tempfile.TemporaryDirectory(prefix="ishamela-bundle-") as tmp:
        tmp_dir = Path(tmp)
        sqlite_tmp = tmp_dir / f"book_{book.book_id}.sqlite"

        conn = _open_sqlite(sqlite_tmp)
        try:
            _create_schema(conn)
            page_count, non_empty_norm, source_to_id = _insert_pages(
                conn, pages_path
            )
            if page_count == 0:
                raise BundleBuildError(
                    f"empty page set for book_id={book.book_id}"
                )
            if non_empty_norm == 0:
                raise BundleBuildError(
                    f"normalization producing empty index for book_id={book.book_id}"
                )
            if toc_path is None:
                candidate = pages_path.with_name("toc.jsonl")
                toc_path = candidate if candidate.is_file() else None
            if toc_path is not None:
                _insert_toc(conn, toc_path, source_to_id)
            _write_meta(
                conn,
                book=book,
                page_count=page_count,
                source_revision=source_revision,
                source_dataset=source_dataset,
            )
            if betaka:
                conn.execute(
                    "INSERT INTO meta (key, value) VALUES (?, ?)",
                    ("betaka", betaka),
                )
            conn.commit()
            conn.execute("VACUUM")
            conn.execute("PRAGMA optimize")
        finally:
            conn.close()

        sqlite_bytes = sqlite_tmp.stat().st_size
        _compress_zstd(sqlite_tmp, isb_path)
        if kept_sqlite is not None:
            kept_sqlite.write_bytes(sqlite_tmp.read_bytes())

    isb_bytes = isb_path.stat().st_size
    digest = _sha256_file(isb_path)
    sidecar = {
        "book_id": book.book_id,
        "title": book.title,
        "author": book.author,
        "category": book.category_name,
        "page_count": page_count,
        "isb_bytes": isb_bytes,
        "sqlite_bytes": sqlite_bytes,
        "sha256": digest,
        "schema_version": SCHEMA_VERSION,
        "norm_version": NORM_VERSION,
    }
    sidecar_path.write_text(
        json.dumps(sidecar, ensure_ascii=False, separators=(",", ":"), sort_keys=True)
        + "\n",
        encoding="utf-8",
    )
    return BundleResult(
        isb_path=isb_path,
        sqlite_path=kept_sqlite,
        sidecar_path=sidecar_path,
        sha256=digest,
        page_count=page_count,
        isb_bytes=isb_bytes,
        sqlite_bytes=sqlite_bytes,
    )


def decompress_isb(isb_path: Path, sqlite_path: Path) -> None:
    """Decompress a ``.isb`` bundle to a SQLite file (tests / inspection)."""
    dctx = zstd.ZstdDecompressor()
    with isb_path.open("rb") as fin, sqlite_path.open("wb") as fout:
        dctx.copy_stream(fin, fout)


# --- Hugging Face helpers -------------------------------------------------


def resolve_dataset_revision(revision: str | None = None) -> str:
    api = HfApi()
    info = api.dataset_info(SOURCE_DATASET, revision=revision)
    if not info.sha:
        raise BundleBuildError("could not resolve Hugging Face dataset revision")
    return info.sha


def _index_book_pages_paths(revision: str) -> dict[int, str]:
    api = HfApi()
    info = api.dataset_info(SOURCE_DATASET, revision=revision)
    index: dict[int, str] = {}
    for sibling in info.siblings or []:
        name = sibling.rfilename
        m = _BOOK_PAGES_RE.search(name)
        if not m:
            continue
        book_id = int(m.group(1))
        index[book_id] = name
    return index


def _download(repo_path: str, *, revision: str, local_dir: Path) -> Path:
    path = hf_hub_download(
        SOURCE_DATASET,
        repo_path,
        repo_type="dataset",
        revision=revision,
        local_dir=str(local_dir),
    )
    return Path(path)


def load_book_meta_from_parquet(
    parquet_path: Path, book_id: int
) -> BookMeta:
    df = pl.read_parquet(parquet_path)
    rows = df.filter(pl.col("book_id") == book_id)
    if rows.height == 0:
        raise BundleBuildError(f"missing book id: {book_id}")
    row = rows.row(0, named=True)
    title = row.get("title_ar")
    author = row.get("main_author_name_ar")
    category_id = row.get("category_id")
    category_name = row.get("category_name_ar")
    if not title or author is None or category_id is None or not category_name:
        raise BundleBuildError(
            f"incomplete metadata for book_id={book_id}"
        )
    return BookMeta(
        book_id=int(book_id),
        title=str(title),
        author=str(author),
        category_id=int(category_id),
        category_name=str(category_name),
    )


def build_bundle(
    book_id: int,
    out_dir: Path,
    *,
    hf_cache: Path,
    revision: str | None = None,
    keep_sqlite: bool = False,
    pages_index: dict[int, str] | None = None,
) -> BundleResult:
    """Download one book from Hugging Face and build its ``.isb`` bundle."""
    resolved = resolve_dataset_revision(revision)
    hf_cache.mkdir(parents=True, exist_ok=True)
    meta_path = _download(
        "_meta/book_metadata.parquet", revision=resolved, local_dir=hf_cache
    )
    book = load_book_meta_from_parquet(meta_path, book_id)
    index = pages_index if pages_index is not None else _index_book_pages_paths(resolved)
    pages_repo_path = index.get(book_id)
    if not pages_repo_path:
        raise BundleBuildError(f"missing book id: {book_id} (no pages.jsonl on hub)")
    pages_path = _download(
        pages_repo_path, revision=resolved, local_dir=hf_cache
    )
    return build_bundle_from_paths(
        book=book,
        pages_path=pages_path,
        out_dir=out_dir,
        source_revision=resolved,
        keep_sqlite=keep_sqlite,
    )


def build_all(
    out_dir: Path,
    *,
    hf_cache: Path,
    revision: str | None = None,
    keep_sqlite: bool = False,
) -> list[BundleResult]:
    resolved = resolve_dataset_revision(revision)
    hf_cache.mkdir(parents=True, exist_ok=True)
    meta_path = _download(
        "_meta/book_metadata.parquet", revision=resolved, local_dir=hf_cache
    )
    index = _index_book_pages_paths(resolved)
    df = pl.read_parquet(meta_path)
    book_ids = sorted(int(x) for x in df["book_id"].to_list())
    results: list[BundleResult] = []
    for book_id in book_ids:
        results.append(
            build_bundle(
                book_id,
                out_dir,
                hf_cache=hf_cache,
                revision=resolved,
                keep_sqlite=keep_sqlite,
                pages_index=index,
            )
        )
    return results
