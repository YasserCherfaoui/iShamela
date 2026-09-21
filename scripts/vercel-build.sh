#!/usr/bin/env bash
# Build Flutter web for Vercel apex (/ base href — not GitHub Pages /iShamela/).
set -euo pipefail

FLUTTER_SDK="${FLUTTER_SDK:-$HOME/flutter}"
export PATH="$FLUTTER_SDK/bin:$PATH"

if [[ ! -x "$FLUTTER_SDK/bin/flutter" ]]; then
  echo "Flutter SDK missing at $FLUTTER_SDK — installCommand must run first" >&2
  exit 1
fi

cd app
flutter build web --release --base-href /
