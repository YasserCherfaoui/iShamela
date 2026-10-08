#!/usr/bin/env bash
# Stamp a Flutter web output with the git SHA (SPEC-030).
# Usage: scripts/stamp-web-build.sh <web-dir> <sha>
# An empty sha writes {"build_id":""} and leaves the index.html placeholder.
set -euo pipefail

WEB_DIR="${1:?web output directory}"
SHA="${2-}"
INDEX="$WEB_DIR/index.html"

if [[ ! -f "$INDEX" ]]; then
  echo "stamp-web-build: missing $INDEX" >&2
  exit 1
fi

python3 - "$INDEX" "$WEB_DIR/shell-version.json" "$SHA" <<'PY'
import json
import pathlib
import sys

index_path, version_path, sha = sys.argv[1:]
index = pathlib.Path(index_path)
if sha:
    text = index.read_text()
    if "__ISHAMELA_BUILD_ID__" not in text:
        sys.exit("stamp-web-build: index.html has no __ISHAMELA_BUILD_ID__")
    index.write_text(text.replace("__ISHAMELA_BUILD_ID__", sha))
pathlib.Path(version_path).write_text(
    json.dumps({"build_id": sha}) + "\n",
)
PY
