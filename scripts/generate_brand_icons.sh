#!/usr/bin/env bash
# SPEC-020 BR-03..06 — generate all brand rasters from icon-master.svg.
# Requires: rsvg-convert (librsvg).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MASTER="$ROOT/app/assets/brand/icon-master.svg"
OUT="$ROOT/app/assets/brand/generated"
FG_SAFE="$ROOT/app/assets/brand/icon-foreground.svg"
MONO="$ROOT/app/assets/brand/icon-monochrome.svg"
NIGHT="$ROOT/app/assets/brand/icon-night.svg"

if [[ ! -f "$MASTER" ]]; then
  echo "missing $MASTER" >&2
  exit 1
fi
if ! command -v rsvg-convert >/dev/null 2>&1; then
  echo "rsvg-convert required (brew install librsvg)" >&2
  exit 1
fi

mkdir -p "$OUT"/{android/mipmap-mdpi,android/mipmap-hdpi,android/mipmap-xhdpi,android/mipmap-xxhdpi,android/mipmap-xxxhdpi}
mkdir -p "$OUT"/{android/mipmap-anydpi-v26,ios,web,desktop,splash}

# Foreground-only (no field, no inset rules) for adaptive safe-zone compositing.
# Scale glyph content into ~66% of the canvas.
cat > "$FG_SAFE" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108" width="108" height="108">
  <g transform="translate(54 54) scale(2.85) translate(-12 -12)">
    <g fill="#C6A15B" transform="translate(12 6.2)">
      <path d="M0,-2.4 L0.55,-0.55 L2.4,0 L0.55,0.55 L0,2.4 L-0.55,0.55 L-2.4,0 L-0.55,-0.55 Z"/>
      <circle r="0.45"/>
    </g>
    <g fill="none" stroke="#F2E8CF" stroke-width="0.55" stroke-linecap="round" stroke-linejoin="round">
      <path d="M12 10.2 V18.6"/>
      <path d="M12 10.2 C10.2 9.6, 7.4 9.5, 5.6 10.3 C5.2 10.5, 5 10.8, 5 11.2 V17.6 C5 18.1, 5.3 18.4, 5.8 18.2 C7.6 17.5, 10.2 17.5, 12 18.1"/>
      <path d="M12 10.2 C13.8 9.6, 16.6 9.5, 18.4 10.3 C18.8 10.5, 19 10.8, 19 11.2 V17.6 C19 18.1, 18.7 18.4, 18.2 18.2 C16.4 17.5, 13.8 17.5, 12 18.1"/>
    </g>
  </g>
</svg>
EOF

# Monochrome (Android 13 themed): ink single-color glyph on transparent.
cat > "$MONO" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108" width="108" height="108">
  <g transform="translate(54 54) scale(2.85) translate(-12 -12)" fill="#1F2A24" stroke="#1F2A24">
    <g transform="translate(12 6.2)" stroke="none">
      <path d="M0,-2.4 L0.55,-0.55 L2.4,0 L0.55,0.55 L0,2.4 L-0.55,0.55 L-2.4,0 L-0.55,-0.55 Z"/>
      <circle r="0.45"/>
    </g>
    <g fill="none" stroke-width="0.55" stroke-linecap="round" stroke-linejoin="round">
      <path d="M12 10.2 V18.6"/>
      <path d="M12 10.2 C10.2 9.6, 7.4 9.5, 5.6 10.3 C5.2 10.5, 5 10.8, 5 11.2 V17.6 C5 18.1, 5.3 18.4, 5.8 18.2 C7.6 17.5, 10.2 17.5, 12 18.1"/>
      <path d="M12 10.2 C13.8 9.6, 16.6 9.5, 18.4 10.3 C18.8 10.5, 19 10.8, 19 11.2 V17.6 C19 18.1, 18.7 18.4, 18.2 18.2 C16.4 17.5, 13.8 17.5, 12 18.1"/>
    </g>
  </g>
</svg>
EOF

# Night full-bleed (iOS dark): gold + paper on #101B17
cat > "$NIGHT" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="1024" height="1024">
  <rect width="24" height="24" fill="#101B17"/>
  <g fill="#C6A15B" transform="translate(12 6.2)">
    <path d="M0,-2.4 L0.55,-0.55 L2.4,0 L0.55,0.55 L0,2.4 L-0.55,0.55 L-2.4,0 L-0.55,-0.55 Z"/>
    <circle r="0.45"/>
  </g>
  <g fill="none" stroke="#F2E8CF" stroke-width="0.55" stroke-linecap="round" stroke-linejoin="round">
    <path d="M12 10.2 V18.6"/>
    <path d="M12 10.2 C10.2 9.6, 7.4 9.5, 5.6 10.3 C5.2 10.5, 5 10.8, 5 11.2 V17.6 C5 18.1, 5.3 18.4, 5.8 18.2 C7.6 17.5, 10.2 17.5, 12 18.1"/>
    <path d="M12 10.2 C13.8 9.6, 16.6 9.5, 18.4 10.3 C18.8 10.5, 19 10.8, 19 11.2 V17.6 C19 18.1, 18.7 18.4, 18.2 18.2 C16.4 17.5, 13.8 17.5, 12 18.1"/>
  </g>
</svg>
EOF

render() {
  local src="$1" size="$2" dest="$3"
  rsvg-convert -w "$size" -h "$size" "$src" -o "$dest"
}

# Master full (with rules) — used ≥64px
for s in 64 128 256 512 1024; do
  render "$MASTER" "$s" "$OUT/master-$s.png"
done

# Splash / native splash — mark on field, NO inset rules (SP-01; rules are master-only).
SPLASH_SVG="$ROOT/app/assets/brand/icon-splash.svg"
cat > "$SPLASH_SVG" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="1024" height="1024">
  <rect width="24" height="24" fill="#0E3B30"/>
  <g fill="#C6A15B" transform="translate(12 6.2)">
    <path d="M0,-2.4 L0.55,-0.55 L2.4,0 L0.55,0.55 L0,2.4 L-0.55,0.55 L-2.4,0 L-0.55,-0.55 Z"/>
    <circle r="0.45"/>
  </g>
  <g fill="none" stroke="#F2E8CF" stroke-width="0.55" stroke-linecap="round" stroke-linejoin="round">
    <path d="M12 10.2 V18.6"/>
    <path d="M12 10.2 C10.2 9.6, 7.4 9.5, 5.6 10.3 C5.2 10.5, 5 10.8, 5 11.2 V17.6 C5 18.1, 5.3 18.4, 5.8 18.2 C7.6 17.5, 10.2 17.5, 12 18.1"/>
    <path d="M12 10.2 C13.8 9.6, 16.6 9.5, 18.4 10.3 C18.8 10.5, 19 10.8, 19 11.2 V17.6 C19 18.1, 18.7 18.4, 18.2 18.2 C16.4 17.5, 13.8 17.5, 12 18.1"/>
    <path d="M7.2 12.4 C8.6 12.0, 10.4 12.0, 11.4 12.3" stroke-opacity="0.55" stroke-width="0.35"/>
    <path d="M7.2 14.0 C8.6 13.6, 10.4 13.6, 11.4 13.9" stroke-opacity="0.55" stroke-width="0.35"/>
    <path d="M12.6 12.3 C13.6 12.0, 15.4 12.0, 16.8 12.4" stroke-opacity="0.55" stroke-width="0.35"/>
    <path d="M12.6 13.9 C13.6 13.6, 15.4 13.6, 16.8 14.0" stroke-opacity="0.55" stroke-width="0.35"/>
  </g>
</svg>
EOF
render "$SPLASH_SVG" 288 "$OUT/splash/splash.png"
render "$SPLASH_SVG" 1152 "$OUT/splash/splash-android12.png"

# Android legacy launcher mipmaps (full-bleed)
render "$MASTER" 48  "$OUT/android/mipmap-mdpi/ic_launcher.png"
render "$MASTER" 72  "$OUT/android/mipmap-hdpi/ic_launcher.png"
render "$MASTER" 96  "$OUT/android/mipmap-xhdpi/ic_launcher.png"
render "$MASTER" 144 "$OUT/android/mipmap-xxhdpi/ic_launcher.png"
render "$MASTER" 192 "$OUT/android/mipmap-xxxhdpi/ic_launcher.png"

# Adaptive layers
render_adaptive() {
  local dens="$1" size="$2"
  local dir="$OUT/android/mipmap-$dens"
  mkdir -p "$dir"
  # solid background
  local bg_svg
  bg_svg="$(mktemp -t ishamela-bg).svg"
  printf '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1 1"><rect width="1" height="1" fill="#0E3B30"/></svg>' > "$bg_svg"
  rsvg-convert -w "$size" -h "$size" "$bg_svg" -o "$dir/ic_launcher_background.png"
  rm -f "$bg_svg"
  render "$FG_SAFE" "$size" "$dir/ic_launcher_foreground.png"
  render "$MONO" "$size" "$dir/ic_launcher_monochrome.png"
}

render_adaptive mdpi 108
render_adaptive hdpi 162
render_adaptive xhdpi 216
render_adaptive xxhdpi 324
render_adaptive xxxhdpi 432

# iOS AppIcon sizes (full-bleed)
declare -a IOS=(20 29 40 58 60 76 80 87 120 152 167 180 1024)
for s in "${IOS[@]}"; do
  render "$MASTER" "$s" "$OUT/ios/icon-$s.png"
done
render "$NIGHT" 1024 "$OUT/ios/icon-1024-dark.png"

# Web / PWA
render "$MASTER" 16  "$OUT/web/favicon-16.png"
render "$MASTER" 32  "$OUT/web/favicon-32.png"
render "$MASTER" 48  "$OUT/web/favicon-48.png"
render "$MASTER" 192 "$OUT/web/icon-192.png"
render "$MASTER" 512 "$OUT/web/icon-512.png"
render "$MASTER" 512 "$OUT/web/maskable-512.png"

# Desktop
render "$MASTER" 256 "$OUT/desktop/icon-256.png"
render "$MASTER" 512 "$OUT/desktop/icon-512.png"

# Inventory for tests
{
  echo "master-64.png"
  echo "master-128.png"
  echo "master-256.png"
  echo "master-512.png"
  echo "master-1024.png"
  echo "splash/splash.png"
  echo "splash/splash-android12.png"
  echo "android/mipmap-xxxhdpi/ic_launcher_foreground.png"
  echo "android/mipmap-xxxhdpi/ic_launcher_monochrome.png"
  echo "ios/icon-1024.png"
  echo "web/favicon-32.png"
  echo "web/maskable-512.png"
  echo "desktop/icon-512.png"
} > "$OUT/inventory.txt"

# Sync into Flutter platform trees (Android / iOS / web).
RES="$ROOT/app/android/app/src/main/res"
if [[ -d "$RES" ]]; then
  for dens in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
    cp "$OUT/android/mipmap-$dens/ic_launcher.png" "$RES/mipmap-$dens/ic_launcher.png"
    cp "$OUT/android/mipmap-$dens/ic_launcher_foreground.png" "$RES/mipmap-$dens/"
    cp "$OUT/android/mipmap-$dens/ic_launcher_background.png" "$RES/mipmap-$dens/"
    cp "$OUT/android/mipmap-$dens/ic_launcher_monochrome.png" "$RES/mipmap-$dens/"
  done
  mkdir -p "$RES/mipmap-anydpi-v26"
  cat > "$RES/mipmap-anydpi-v26/ic_launcher.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>
</adaptive-icon>
XML
fi

IOS_SET="$ROOT/app/ios/Runner/Assets.xcassets/AppIcon.appiconset"
if [[ -d "$IOS_SET" ]]; then
  cp "$OUT/ios/icon-20.png"  "$IOS_SET/Icon-App-20x20@1x.png"
  cp "$OUT/ios/icon-40.png"  "$IOS_SET/Icon-App-20x20@2x.png"
  cp "$OUT/ios/icon-60.png"  "$IOS_SET/Icon-App-20x20@3x.png"
  cp "$OUT/ios/icon-29.png"  "$IOS_SET/Icon-App-29x29@1x.png"
  cp "$OUT/ios/icon-58.png"  "$IOS_SET/Icon-App-29x29@2x.png"
  cp "$OUT/ios/icon-87.png"  "$IOS_SET/Icon-App-29x29@3x.png"
  cp "$OUT/ios/icon-40.png"  "$IOS_SET/Icon-App-40x40@1x.png"
  cp "$OUT/ios/icon-80.png"  "$IOS_SET/Icon-App-40x40@2x.png"
  cp "$OUT/ios/icon-120.png" "$IOS_SET/Icon-App-40x40@3x.png"
  cp "$OUT/ios/icon-120.png" "$IOS_SET/Icon-App-60x60@2x.png"
  cp "$OUT/ios/icon-180.png" "$IOS_SET/Icon-App-60x60@3x.png"
  cp "$OUT/ios/icon-76.png"  "$IOS_SET/Icon-App-76x76@1x.png"
  cp "$OUT/ios/icon-152.png" "$IOS_SET/Icon-App-76x76@2x.png"
  cp "$OUT/ios/icon-167.png" "$IOS_SET/Icon-App-83.5x83.5@2x.png"
  cp "$OUT/ios/icon-1024.png" "$IOS_SET/Icon-App-1024x1024@1x.png"
fi

if [[ -d "$ROOT/app/web" ]]; then
  cp "$OUT/web/favicon-32.png" "$ROOT/app/web/favicon.png"
  mkdir -p "$ROOT/app/web/icons"
  cp "$OUT/web/icon-192.png" "$ROOT/app/web/icons/Icon-192.png"
  cp "$OUT/web/icon-512.png" "$ROOT/app/web/icons/Icon-512.png"
  cp "$OUT/web/maskable-512.png" "$ROOT/app/web/icons/Icon-maskable-512.png"
fi

echo "Generated brand rasters under $OUT"
wc -l "$OUT/inventory.txt"
