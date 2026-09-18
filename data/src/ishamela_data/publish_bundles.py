"""Publish catalog + book bundles to Hugging Face (SPEC-007)."""

from __future__ import annotations

import hashlib
import json
import sqlite3
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import jsonschema
import zstandard as zstd
from huggingface_hub import HfApi

DEFAULT_REPO = "yassercherfaoui/ishamela-bundles"
DEFAULT_REVISION = "main"
CATALOG_ZST_MAX_BYTES = 15 * 1024 * 1024  # SPEC-003 size gate


class PublishError(Exception):
    """Raised when a publish plan cannot be built or executed."""


@dataclass(frozen=True)
class UploadItem:
    local_path: Path
    repo_path: str
    sha256: str
    size: int


def _sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def _default_schema_path() -> Path:
    # data/src/ishamela_data/publish_bundles.py → data/schemas/
    return Path(__file__).resolve().parents[2] / "schemas" / "catalog.schema.json"


def _load_manifest(catalog_dir: Path, schema_path: Path) -> dict[str, Any]:
    manifest_path = catalog_dir / "catalog.json"
    if not manifest_path.is_file():
        raise PublishError(f"missing catalog.json under {catalog_dir}")
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise PublishError(f"catalog.json is not valid JSON: {exc}") from exc
    if not schema_path.is_file():
        raise PublishError(f"missing catalog schema at {schema_path}")
    schema = json.loads(schema_path.read_text(encoding="utf-8"))
    try:
        jsonschema.validate(instance=manifest, schema=schema)
    except jsonschema.ValidationError as exc:
        raise PublishError(f"catalog.json failed schema validation: {exc.message}") from exc
    return manifest


def _books_from_catalog_zst(zst_path: Path) -> list[tuple[str, str, int]]:
    """Return list of (filename, sha256, isb_bytes) from catalog.sqlite.zst."""
    if not zst_path.is_file():
        raise PublishError(f"missing {zst_path.name}")
    dctx = zstd.ZstdDecompressor()
    with tempfile.NamedTemporaryFile(suffix=".sqlite", delete=False) as tmp:
        tmp_path = Path(tmp.name)
    try:
        with zst_path.open("rb") as fin, tmp_path.open("wb") as fout:
            dctx.copy_stream(fin, fout)
        conn = sqlite3.connect(tmp_path)
        try:
            rows = conn.execute(
                "SELECT filename, sha256, isb_bytes FROM books ORDER BY book_id"
            ).fetchall()
        finally:
            conn.close()
    finally:
        tmp_path.unlink(missing_ok=True)
    if not rows:
        raise PublishError("catalog has zero books")
    return [(str(fn), str(digest), int(nbytes)) for fn, digest, nbytes in rows]


def plan_publish(
    *,
    catalog_dir: Path,
    books_dir: Path,
    schema_path: Path | None = None,
    enforce_catalog_size_gate: bool = False,
) -> list[UploadItem]:
    """Validate artifacts and return the ordered upload plan (no network)."""
    catalog_dir = catalog_dir.resolve()
    books_dir = books_dir.resolve()
    schema = (schema_path or _default_schema_path()).resolve()

    manifest = _load_manifest(catalog_dir, schema)
    zst_meta = manifest["catalog_sqlite_zst"]
    zst_path = catalog_dir / Path(zst_meta["path"]).name
    # Allow either catalog/catalog.sqlite.zst layout on disk or flat catalog.sqlite.zst
    if not zst_path.is_file():
        nested = catalog_dir / zst_meta["path"]
        if nested.is_file():
            zst_path = nested
        else:
            alt = catalog_dir / "catalog.sqlite.zst"
            if alt.is_file():
                zst_path = alt
            else:
                raise PublishError("missing catalog.sqlite.zst")

    zst_digest = _sha256_file(zst_path)
    if zst_digest != zst_meta["sha256"]:
        raise PublishError(
            f"catalog.sqlite.zst sha256 mismatch: on-disk={zst_digest} "
            f"manifest={zst_meta['sha256']}"
        )
    zst_size = zst_path.stat().st_size
    if zst_size != int(zst_meta["bytes"]):
        raise PublishError(
            f"catalog.sqlite.zst size mismatch: on-disk={zst_size} "
            f"manifest={zst_meta['bytes']}"
        )
    if enforce_catalog_size_gate and zst_size >= CATALOG_ZST_MAX_BYTES:
        raise PublishError(
            f"catalog.sqlite.zst is {zst_size} bytes; SPEC-003 gate is "
            f"< {CATALOG_ZST_MAX_BYTES} for production publishes"
        )

    items: list[UploadItem] = [
        UploadItem(
            local_path=catalog_dir / "catalog.json",
            repo_path="catalog/catalog.json",
            sha256=_sha256_file(catalog_dir / "catalog.json"),
            size=(catalog_dir / "catalog.json").stat().st_size,
        ),
        UploadItem(
            local_path=zst_path,
            repo_path="catalog/catalog.sqlite.zst",
            sha256=zst_digest,
            size=zst_size,
        ),
    ]

    for filename, expected_sha, isb_bytes in _books_from_catalog_zst(zst_path):
        # Browse-only rows (meta catalog) have isb_bytes=0 — skip for publish.
        if isb_bytes <= 0 or expected_sha == "0" * 64:
            continue
        local = books_dir / filename
        if not local.is_file():
            # Also accept books/ nested under books_dir
            nested = books_dir / "books" / filename
            if nested.is_file():
                local = nested
            else:
                raise PublishError(f"missing book file {filename} under {books_dir}")
        digest = _sha256_file(local)
        if digest != expected_sha:
            raise PublishError(
                f"sha256 mismatch for {filename}: on-disk={digest} catalog={expected_sha}"
            )
        items.append(
            UploadItem(
                local_path=local,
                repo_path=f"books/{filename}",
                sha256=digest,
                size=local.stat().st_size,
            )
        )

    return items


def format_plan(items: list[UploadItem]) -> str:
    lines = [f"{it.repo_path}\t{it.size}\t{it.sha256}" for it in items]
    return "\n".join(lines) + ("\n" if lines else "")


def publish(
    *,
    catalog_dir: Path,
    books_dir: Path,
    repo: str = DEFAULT_REPO,
    revision: str = DEFAULT_REVISION,
    dry_run: bool = False,
    schema_path: Path | None = None,
    enforce_catalog_size_gate: bool = False,
    api: HfApi | None = None,
    token: str | None = None,
) -> list[UploadItem]:
    """Validate and optionally upload to Hugging Face."""
    items = plan_publish(
        catalog_dir=catalog_dir,
        books_dir=books_dir,
        schema_path=schema_path,
        enforce_catalog_size_gate=enforce_catalog_size_gate,
    )
    if dry_run:
        return items

    client = api or HfApi(token=token)
    client.create_repo(
        repo_id=repo,
        repo_type="dataset",
        exist_ok=True,
        private=False,
    )
    for item in items:
        # Skip when remote blob already matches (idempotent re-run).
        try:
            infos = list(
                client.get_paths_info(
                    repo_id=repo,
                    paths=[item.repo_path],
                    repo_type="dataset",
                    revision=revision,
                )
            )
        except Exception:
            infos = []
        remote_oid = None
        if infos:
            info = infos[0]
            lfs = getattr(info, "lfs", None)
            if lfs is not None and getattr(lfs, "sha256", None):
                remote_oid = lfs.sha256
            elif getattr(info, "blob_id", None):
                remote_oid = None  # non-LFS: always re-upload to be safe
        if remote_oid == item.sha256:
            continue
        client.upload_file(
            path_or_fileobj=str(item.local_path),
            path_in_repo=item.repo_path,
            repo_id=repo,
            repo_type="dataset",
            revision=revision,
            commit_message=f"publish {item.repo_path}",
        )
    return items
