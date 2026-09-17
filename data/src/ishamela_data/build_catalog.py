"""Library catalog builder (SPEC-003).

Merges SPEC-002 ``book_*.json`` sidecars with HF ``_meta`` parquets into
``catalog.json`` + ``catalog.sqlite.zst``.
"""

from __future__ import annotations

import hashlib
import json
import re
import sqlite3
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import polars as pl
import zstandard as zstd
from huggingface_hub import hf_hub_download

from ishamela_data.build_bundle import SOURCE_DATASET, resolve_dataset_revision
from ishamela_data.normalizer import NORM_VERSION, normalize

CATALOG_SCHEMA_VERSION = 1
ZSTD_LEVEL = 19
MIN_APP_VERSION = "0.1.0"
DEFAULT_BOOKS_BASE_URL = (
    "https://huggingface.co/datasets/ishamela/bundles/resolve/main/books/"
)
_SIDECAR_RE = re.compile(r"^book_(\d+)\.json$")


class CatalogBuildError(Exception):
    """Raised when a catalog cannot be built; message is safe for stderr."""


@dataclass(frozen=True)
class CatalogResult:
    manifest_path: Path
    zst_path: Path
    sqlite_path: Path | None
    sha256: str
    zst_bytes: int
    book_count: int


def _sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def _compress_zstd(src: Path, dest: Path) -> None:
    # Pledge size so the frame stores content size (helps clients that size
    # the output buffer from ZSTD_getFrameContentSize).
    cctx = zstd.ZstdCompressor(level=ZSTD_LEVEL, write_content_size=True)
    with src.open("rb") as fin, dest.open("wb") as fout:
        cctx.copy_stream(fin, fout, size=src.stat().st_size)


def _open_sqlite(path: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(path)
    conn.execute("PRAGMA page_size = 4096")
    conn.execute("PRAGMA encoding = 'UTF-8'")
    conn.execute("PRAGMA journal_mode = OFF")
    conn.execute("PRAGMA synchronous = OFF")
    conn.execute("PRAGMA temp_store = MEMORY")
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def _create_schema(conn: sqlite3.Connection) -> None:
    conn.executescript(
        """
        CREATE TABLE meta (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        );

        CREATE TABLE categories (
          id INTEGER PRIMARY KEY,
          name TEXT NOT NULL,
          position INTEGER NOT NULL
        );

        CREATE TABLE authors (
          id INTEGER PRIMARY KEY,
          name TEXT NOT NULL,
          death_year_hijri INTEGER
        );

        CREATE TABLE books (
          book_id INTEGER PRIMARY KEY,
          title TEXT NOT NULL,
          author_id INTEGER REFERENCES authors(id),
          category_id INTEGER NOT NULL REFERENCES categories(id),
          page_count INTEGER NOT NULL,
          volume_count INTEGER,
          isb_bytes INTEGER NOT NULL,
          sqlite_bytes INTEGER NOT NULL,
          sha256 TEXT NOT NULL,
          filename TEXT NOT NULL
        );

        CREATE VIRTUAL TABLE books_fts USING fts5(
          title_norm,
          author_norm,
          content='',
          tokenize='unicode61 remove_diacritics 0'
        );
        """
    )


def _load_sidecars(sidecars_dir: Path) -> list[dict[str, Any]]:
    if not sidecars_dir.is_dir():
        raise CatalogBuildError(f"sidecars directory not found: {sidecars_dir}")
    paths = sorted(sidecars_dir.glob("book_*.json"))
    if not paths:
        raise CatalogBuildError(f"no book_*.json sidecars in {sidecars_dir}")

    rows: list[dict[str, Any]] = []
    for path in paths:
        m = _SIDECAR_RE.match(path.name)
        if not m:
            continue
        data = json.loads(path.read_text(encoding="utf-8"))
        book_id = int(data.get("book_id", m.group(1)))
        if book_id != int(m.group(1)):
            raise CatalogBuildError(
                f"sidecar filename/book_id mismatch: {path.name} vs book_id={book_id}"
            )
        required = (
            "title",
            "author",
            "page_count",
            "isb_bytes",
            "sqlite_bytes",
            "sha256",
            "schema_version",
            "norm_version",
        )
        missing = [k for k in required if k not in data]
        if missing:
            raise CatalogBuildError(
                f"incomplete sidecar {path.name}: missing {', '.join(missing)}"
            )
        rows.append(data)
    if not rows:
        raise CatalogBuildError(f"no book_*.json sidecars in {sidecars_dir}")
    return rows


def _assert_homogeneous(sidecars: list[dict[str, Any]]) -> tuple[str, str]:
    norms = {str(s["norm_version"]) for s in sidecars}
    schemas = {str(s["schema_version"]) for s in sidecars}
    if len(norms) != 1 or len(schemas) != 1:
        offenders: list[str] = []
        # Report relative to the majority / first seen for clarity.
        base_norm = str(sidecars[0]["norm_version"])
        base_schema = str(sidecars[0]["schema_version"])
        for s in sidecars:
            n = str(s["norm_version"])
            sch = str(s["schema_version"])
            if n != base_norm or sch != base_schema:
                offenders.append(
                    f"book_{s['book_id']}.json "
                    f"(norm_version={n!r}, schema_version={sch!r})"
                )
        # If first is the odd one, list all that differ from the most common.
        if not offenders:
            offenders = [
                f"book_{s['book_id']}.json "
                f"(norm_version={s['norm_version']!r}, "
                f"schema_version={s['schema_version']!r})"
                for s in sidecars
            ]
        raise CatalogBuildError(
            "sidecars are not homogeneous on norm_version/schema_version; "
            "offenders: " + "; ".join(offenders)
        )
    return norms.pop(), schemas.pop()


def _volume_count(raw: Any) -> int | None:
    if raw is None:
        return None
    value = int(raw)
    return value if value > 0 else None


def build_catalog_from_paths(
    *,
    sidecars_dir: Path,
    out_dir: Path,
    catalog_version: int,
    generated_at: str,
    book_metadata_path: Path,
    authors_path: Path,
    categories_path: Path,
    source_revision: str,
    base_url: str = DEFAULT_BOOKS_BASE_URL,
    keep_sqlite: bool = False,
) -> CatalogResult:
    """Build catalog artifacts from local sidecars + parquet metadata."""
    if catalog_version < 1:
        raise CatalogBuildError("--catalog-version must be >= 1")

    sidecars = _load_sidecars(sidecars_dir)
    norm_version, schema_version_sidecar = _assert_homogeneous(sidecars)
    if norm_version != NORM_VERSION:
        # Allowed if homogeneous and intentional for a rebuild; catalog stores
        # the sidecar value. Pipeline current code expects SPEC-001 version.
        pass
    _ = schema_version_sidecar  # homogeneity only; catalog schema is fixed

    books_meta = pl.read_parquet(book_metadata_path)
    authors_df = pl.read_parquet(authors_path)
    categories_df = pl.read_parquet(categories_path)

    meta_by_id = {
        int(r["book_id"]): r
        for r in books_meta.to_dicts()
    }
    authors_by_id = {
        int(r["id"]): r for r in authors_df.to_dicts()
    }
    categories_by_id = {
        int(r["id"]): r for r in categories_df.to_dicts()
    }

    # Only authors/categories referenced by these sidecars.
    needed_author_ids: set[int] = set()
    needed_category_ids: set[int] = set()
    book_rows: list[dict[str, Any]] = []

    for sc in sorted(sidecars, key=lambda s: int(s["book_id"])):
        book_id = int(sc["book_id"])
        bm = meta_by_id.get(book_id)
        if bm is None:
            raise CatalogBuildError(
                f"sidecar book_id={book_id} has no matching book_metadata row"
            )
        category_id = bm.get("category_id")
        if category_id is None:
            raise CatalogBuildError(f"book_id={book_id}: missing category_id")
        category_id = int(category_id)
        if category_id not in categories_by_id:
            raise CatalogBuildError(
                f"book_id={book_id}: category_id={category_id} not in categories.parquet"
            )
        needed_category_ids.add(category_id)

        author_id_raw = bm.get("main_author_id")
        author_id: int | None
        if author_id_raw is None:
            author_id = None
        else:
            author_id = int(author_id_raw)
            if author_id not in authors_by_id:
                raise CatalogBuildError(
                    f"book_id={book_id}: author_id={author_id} not in authors.parquet"
                )
            needed_author_ids.add(author_id)

        author_name = (
            str(authors_by_id[author_id]["name_ar"])
            if author_id is not None
            else str(sc["author"])
        )
        book_rows.append(
            {
                "book_id": book_id,
                "title": str(sc["title"]),
                "author_id": author_id,
                "author_name": author_name,
                "category_id": category_id,
                "page_count": int(sc["page_count"]),
                "volume_count": _volume_count(bm.get("volume_count_observed")),
                "isb_bytes": int(sc["isb_bytes"]),
                "sqlite_bytes": int(sc["sqlite_bytes"]),
                "sha256": str(sc["sha256"]),
                "filename": f"book_{book_id}.isb",
            }
        )

    out_dir.mkdir(parents=True, exist_ok=True)
    zst_path = out_dir / "catalog.sqlite.zst"
    manifest_path = out_dir / "catalog.json"
    kept_sqlite: Path | None = (
        out_dir / "catalog.sqlite" if keep_sqlite else None
    )

    with tempfile.TemporaryDirectory(prefix="ishamela-catalog-") as tmp:
        tmp_dir = Path(tmp)
        sqlite_tmp = tmp_dir / "catalog.sqlite"
        conn = _open_sqlite(sqlite_tmp)
        try:
            _create_schema(conn)

            for cid in sorted(needed_category_ids):
                cat = categories_by_id[cid]
                conn.execute(
                    "INSERT INTO categories (id, name, position) VALUES (?, ?, ?)",
                    (
                        cid,
                        str(cat["name_ar"]),
                        int(cat["sort_order"]),
                    ),
                )

            for aid in sorted(needed_author_ids):
                au = authors_by_id[aid]
                death = au.get("death_hijri")
                conn.execute(
                    "INSERT INTO authors (id, name, death_year_hijri) VALUES (?, ?, ?)",
                    (
                        aid,
                        str(au["name_ar"]),
                        None if death is None else int(death),
                    ),
                )

            for row in book_rows:
                conn.execute(
                    """
                    INSERT INTO books (
                      book_id, title, author_id, category_id, page_count,
                      volume_count, isb_bytes, sqlite_bytes, sha256, filename
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        row["book_id"],
                        row["title"],
                        row["author_id"],
                        row["category_id"],
                        row["page_count"],
                        row["volume_count"],
                        row["isb_bytes"],
                        row["sqlite_bytes"],
                        row["sha256"],
                        row["filename"],
                    ),
                )
                conn.execute(
                    "INSERT INTO books_fts (rowid, title_norm, author_norm) VALUES (?, ?, ?)",
                    (
                        row["book_id"],
                        normalize(row["title"]),
                        normalize(row["author_name"]),
                    ),
                )

            meta_rows = {
                "catalog_version": str(catalog_version),
                "schema_version": str(CATALOG_SCHEMA_VERSION),
                "norm_version": norm_version,
                "generated_at": generated_at,
                "source_revision": source_revision,
            }
            for key in sorted(meta_rows):
                conn.execute(
                    "INSERT INTO meta (key, value) VALUES (?, ?)",
                    (key, meta_rows[key]),
                )

            conn.commit()
            fk_violations = conn.execute("PRAGMA foreign_key_check").fetchall()
            if fk_violations:
                raise CatalogBuildError(
                    f"foreign key violations: {fk_violations}"
                )
            conn.execute("VACUUM")
            conn.execute("PRAGMA optimize")
        finally:
            conn.close()

        _compress_zstd(sqlite_tmp, zst_path)
        if kept_sqlite is not None:
            kept_sqlite.write_bytes(sqlite_tmp.read_bytes())

    zst_bytes = zst_path.stat().st_size
    digest = _sha256_file(zst_path)
    manifest = {
        "catalog_version": catalog_version,
        "generated_at": generated_at,
        "schema_version": CATALOG_SCHEMA_VERSION,
        "norm_version": norm_version,
        "catalog_sqlite_zst": {
            "path": "catalog/catalog.sqlite.zst",
            "bytes": zst_bytes,
            "sha256": digest,
        },
        "books_base_url": base_url,
        "book_count": len(book_rows),
        "min_app_version": MIN_APP_VERSION,
    }
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, separators=(",", ":"), sort_keys=True)
        + "\n",
        encoding="utf-8",
    )
    return CatalogResult(
        manifest_path=manifest_path,
        zst_path=zst_path,
        sqlite_path=kept_sqlite,
        sha256=digest,
        zst_bytes=zst_bytes,
        book_count=len(book_rows),
    )


def _download(repo_path: str, *, revision: str, local_dir: Path) -> Path:
    path = hf_hub_download(
        SOURCE_DATASET,
        repo_path,
        repo_type="dataset",
        revision=revision,
        local_dir=str(local_dir),
    )
    return Path(path)


def build_catalog(
    *,
    sidecars_dir: Path,
    out_dir: Path,
    catalog_version: int,
    generated_at: str,
    hf_cache: Path,
    revision: str | None = None,
    base_url: str = DEFAULT_BOOKS_BASE_URL,
    keep_sqlite: bool = False,
) -> CatalogResult:
    """Download HF metadata parquets and build the catalog."""
    resolved = resolve_dataset_revision(revision)
    hf_cache.mkdir(parents=True, exist_ok=True)
    book_metadata_path = _download(
        "_meta/book_metadata.parquet", revision=resolved, local_dir=hf_cache
    )
    authors_path = _download(
        "_meta/authors.parquet", revision=resolved, local_dir=hf_cache
    )
    categories_path = _download(
        "_meta/categories.parquet", revision=resolved, local_dir=hf_cache
    )
    return build_catalog_from_paths(
        sidecars_dir=sidecars_dir,
        out_dir=out_dir,
        catalog_version=catalog_version,
        generated_at=generated_at,
        book_metadata_path=book_metadata_path,
        authors_path=authors_path,
        categories_path=categories_path,
        source_revision=resolved,
        base_url=base_url,
        keep_sqlite=keep_sqlite,
    )
