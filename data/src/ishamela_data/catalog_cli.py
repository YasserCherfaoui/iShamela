"""CLI for SPEC-003: ``ishamela-catalog``."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from ishamela_data.build_catalog import (
    DEFAULT_BOOKS_BASE_URL,
    CatalogBuildError,
    build_catalog,
)


def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="ishamela-catalog",
        description=(
            "Build iShamela catalog.json + catalog.sqlite.zst "
            "from SPEC-002 book sidecars (SPEC-003)."
        ),
    )
    parser.add_argument(
        "--sidecars",
        type=Path,
        required=False,
        help="Directory containing book_*.json sidecars (omit with --from-meta-only)",
    )
    parser.add_argument(
        "--out",
        type=Path,
        required=True,
        help="Output directory for catalog.json and catalog.sqlite.zst",
    )
    parser.add_argument(
        "--catalog-version",
        type=int,
        required=True,
        help="Monotonic catalog version (set by CI)",
    )
    parser.add_argument(
        "--generated-at",
        required=True,
        help="ISO-8601 UTC timestamp, e.g. 2026-09-17T00:00:00Z (for determinism)",
    )
    parser.add_argument(
        "--base-url",
        default=DEFAULT_BOOKS_BASE_URL,
        help=f"Books CDN base URL (default: {DEFAULT_BOOKS_BASE_URL})",
    )
    parser.add_argument(
        "--hf-cache",
        type=Path,
        default=Path("./hf"),
        help="Local Hugging Face download cache (default: ./hf)",
    )
    parser.add_argument(
        "--revision",
        default=None,
        help="Optional HF dataset revision (commit sha or branch)",
    )
    parser.add_argument(
        "--keep-sqlite",
        action="store_true",
        help="Also write uncompressed catalog.sqlite next to the .zst",
    )
    parser.add_argument(
        "--from-meta-only",
        action="store_true",
        help=(
            "Build browse catalog from Shamela4 _meta; if --sidecars is also "
            "set, overlay real .isb download fields for those books"
        ),
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)
    if not args.from_meta_only and not args.sidecars:
        print(
            "ishamela-catalog: --sidecars is required unless --from-meta-only",
            file=sys.stderr,
        )
        return 1
    try:
        result = build_catalog(
            sidecars_dir=args.sidecars or Path("."),
            out_dir=args.out,
            catalog_version=args.catalog_version,
            generated_at=args.generated_at,
            hf_cache=args.hf_cache,
            revision=args.revision,
            base_url=args.base_url,
            keep_sqlite=args.keep_sqlite,
            from_meta_only=args.from_meta_only,
            overlay_sidecars=args.sidecars if args.from_meta_only else None,
        )
        print(
            f"built {result.manifest_path} + {result.zst_path} "
            f"(books={result.book_count}, sha256={result.sha256})",
            file=sys.stderr,
        )
    except CatalogBuildError as exc:
        print(f"ishamela-catalog: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
