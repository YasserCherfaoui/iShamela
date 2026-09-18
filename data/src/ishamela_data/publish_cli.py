"""CLI for SPEC-007: ``ishamela-publish``."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from ishamela_data.publish_bundles import (
    DEFAULT_REPO,
    DEFAULT_REVISION,
    PublishError,
    format_plan,
    publish,
)


def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="ishamela-publish",
        description=(
            "Validate and upload catalog + .isb bundles to Hugging Face "
            "(SPEC-007)."
        ),
    )
    parser.add_argument(
        "--catalog-dir",
        type=Path,
        required=True,
        help="Directory containing catalog.json and catalog.sqlite.zst",
    )
    parser.add_argument(
        "--books-dir",
        type=Path,
        required=True,
        help="Directory containing book_*.isb files",
    )
    parser.add_argument(
        "--repo",
        default=DEFAULT_REPO,
        help=f"HF dataset repo id (default: {DEFAULT_REPO})",
    )
    parser.add_argument(
        "--revision",
        default=DEFAULT_REVISION,
        help=f"HF revision / branch (default: {DEFAULT_REVISION})",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Validate and print the upload plan; do not write to HF",
    )
    parser.add_argument(
        "--schema",
        type=Path,
        default=None,
        help="Path to catalog.schema.json (default: data/schemas/...)",
    )
    parser.add_argument(
        "--enforce-size-gate",
        action="store_true",
        help="Fail if catalog.sqlite.zst is ≥ 15 MB (production publishes)",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)
    try:
        items = publish(
            catalog_dir=args.catalog_dir,
            books_dir=args.books_dir,
            repo=args.repo,
            revision=args.revision,
            dry_run=args.dry_run,
            schema_path=args.schema,
            enforce_catalog_size_gate=args.enforce_size_gate,
        )
    except PublishError as exc:
        print(f"ishamela-publish: {exc}", file=sys.stderr)
        return 1

    sys.stdout.write(format_plan(items))
    if args.dry_run:
        print(
            f"ishamela-publish: dry-run OK ({len(items)} files)",
            file=sys.stderr,
        )
    else:
        print(
            f"ishamela-publish: uploaded/checked {len(items)} files → "
            f"{args.repo}@{args.revision}",
            file=sys.stderr,
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
