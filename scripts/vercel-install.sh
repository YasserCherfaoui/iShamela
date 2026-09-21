#!/usr/bin/env bash
# Install Flutter SDK + app deps for Vercel (SPEC-021 web host).
# Pin must match .github/workflows/build-release.yml FLUTTER_VERSION.
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.32.5}"
FLUTTER_SDK="${FLUTTER_SDK:-$HOME/flutter}"

if [[ ! -x "$FLUTTER_SDK/bin/flutter" ]]; then
  echo "Cloning Flutter $FLUTTER_VERSION → $FLUTTER_SDK"
  git clone \
    --depth 1 \
    --branch "$FLUTTER_VERSION" \
    https://github.com/flutter/flutter.git \
    "$FLUTTER_SDK"
else
  echo "Using existing Flutter at $FLUTTER_SDK"
fi

export PATH="$FLUTTER_SDK/bin:$PATH"
flutter config --no-analytics --enable-web
flutter precache --web

cd app
flutter pub get
