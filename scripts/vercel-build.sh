#!/usr/bin/env bash
# Build Flutter web for Vercel apex (/ base href — not GitHub Pages /iShamela/).
set -euo pipefail

FLUTTER_SDK="${FLUTTER_SDK:-$HOME/flutter}"
export PATH="$FLUTTER_SDK/bin:$PATH"

if [[ ! -x "$FLUTTER_SDK/bin/flutter" ]]; then
  echo "Flutter SDK missing at $FLUTTER_SDK — installCommand must run first" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$REPO_ROOT/app/tool/ensure_firebase_config.sh"

if grep -q "webApiKey = '';" "$REPO_ROOT/app/lib/firebase_local_secrets.dart"; then
  echo "FIREBASE_WEB_API_KEY is not set." >&2
  echo "Add it in the Vercel project environment variables, then redeploy." >&2
  exit 1
fi

cd app
flutter build web --release --base-href /
