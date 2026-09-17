"""CLI for SPEC-002: ``ishamela-build``."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from ishamela_data.build_bundle import BundleBuildError, build_all, build_bundle


def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="ishamela-build",
        description="Build iShamela .isb book bundles from Shamela4_Full_DB (SPEC-002).",
    )
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--book-id", type=int, help="Build a single book by id")
    group.add_argument(
        "--all",
        action="store_true",
        help="Build every book in the corpus (CI use)",
    )
    parser.add_argument(
        "--out",
        type=Path,
        required=True,
        help="Output directory for .isb and .json sidecars",
    )
    parser.add_argument(
        "--hf-cache",
        type=Path,
        default=Path("./hf"),
        help="Local Hugging Face download cache (default: ./hf)",
    )
    parser.add_argument(
        "--keep-sqlite",
        action="store_true",
        help="Also write the uncompressed .sqlite next to the .isb",
    )
    parser.add_argument(
        "--revision",
        default=None,
        help="Optional HF dataset revision (commit sha or branch); default = current main",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)
    try:
        if args.all:
            results = build_all(
                args.out,
                hf_cache=args.hf_cache,
                revision=args.revision,
                keep_sqlite=args.keep_sqlite,
            )
            print(f"built {len(results)} bundles into {args.out}", file=sys.stderr)
        else:
            result = build_bundle(
                args.book_id,
                args.out,
                hf_cache=args.hf_cache,
                revision=args.revision,
                keep_sqlite=args.keep_sqlite,
            )
            print(
                f"built {result.isb_path} "
                f"(pages={result.page_count}, sha256={result.sha256})",
                file=sys.stderr,
            )
    except BundleBuildError as exc:
        print(f"ishamela-build: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
