#!/usr/bin/env bash
# Redraws the README images in docs/images from the real panel: the views are
# rendered offscreen (Tests/RetypoTests/ReadmeShotsTests.swift), then get a
# soft shadow, and the hero gets captions and a crossfaded loop. Run it after
# any visible UI change.
#
# Needs ImageMagick and libwebp: brew install imagemagick webp
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
OUT="docs/images"
RAW="$(mktemp -d)"
trap 'rm -rf "$RAW"' EXIT

for tool in magick img2webp cwebp; do
  command -v "$tool" >/dev/null || { echo "missing $tool: brew install imagemagick webp"; exit 2; }
done

echo "==> Rendering the panel"
if ! RETYPO_README_SHOTS="$RAW" swift test --filter ReadmeShotsTests > "$RAW/swift-test.log" 2>&1; then
  cat "$RAW/swift-test.log"
  exit 1
fi
mkdir -p "$OUT"

FONT=/System/Library/Fonts/SFNS.ttf
CAPTIONS=(
  "Type fast. Don't fix anything."
  "⏎ runs the mode: new text in green, a red pin where text was cut."
  "⌘⇧D shows every change. Any key goes back."
)
HOLDS=(1800 3000 3800)  # ms on each step of the hero loop

# Transparent canvas, so the panel floats on either GitHub theme.
shadow() {  # input output opacity
  magick "$1" \( +clone -background black -shadow "${3}x26+0+18" \) +swap \
    -background none -layers merge +repage "$2"
}

hero() {  # theme caption-color shadow-opacity
  local dir="$RAW/$1" frames=() i next shot m
  for i in 0 1 2; do
    shot=("$dir/$((i + 1))-"*.png)
    shadow "${shot[0]}" "$dir/s$i.png" "$3"
    magick "$dir/s$i.png" -gravity south -background none -splice 0x64 \
      -font "$FONT" -pointsize 27 -fill "$2" -annotate +0+18 "${CAPTIONS[$i]}" "$dir/c$i.png"
  done
  for i in 0 1 2; do
    next=$(( (i + 1) % 3 ))
    magick "$dir/c$i.png" "$dir/c$next.png" -morph 3 -delete 0,-1 "$dir/m$i-%d.png"
    frames+=(-d "${HOLDS[$i]}" "$dir/c$i.png")
    for m in "$dir/m$i-"*.png; do frames+=(-d 60 "$m"); done
  done
  img2webp -loop 0 -lossy -q 82 -m 6 "${frames[@]}" -o "$OUT/hero-$1.webp" >/dev/null 2>&1
}

still() {  # theme shadow-opacity name
  shadow "$RAW/$1/$3.png" "$RAW/$1/s-$3.png" "$2"
  cwebp -quiet -q 85 "$RAW/$1/s-$3.png" -o "$OUT/$3-$1.webp"
}

for theme in light dark; do
  if [ "$theme" = light ]; then color='#59636e'; opacity=22; else color='#9198a1'; opacity=35; fi
  echo "==> $theme"
  hero "$theme" "$color" "$opacity"
  for name in modes enhanced candidates; do still "$theme" "$opacity" "$name"; done
done

du -h "$OUT"/*.webp
