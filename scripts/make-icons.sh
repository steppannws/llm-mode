#!/usr/bin/env bash
# scripts/make-icons.sh — render app/Icon/*.svg into the app's asset catalog
# and docs/images/logo.svg. Needs rsvg-convert (brew install librsvg).
set -euo pipefail
cd "$(dirname "$0")/.."

SRC=app/Icon
XC=app/LLMMode/Assets.xcassets
mkdir -p "$XC/AppIcon.appiconset" "$XC/MenuOff.imageset" "$XC/MenuOn.imageset"
echo '{ "info": { "author": "xcode", "version": 1 } }' > "$XC/Contents.json"

# App icon: macOS sizes 16–512 pt at 1x and 2x
images=""
for pt in 16 32 128 256 512; do
  for scale in 1 2; do
    px=$((pt * scale)); name="icon_${pt}x${pt}@${scale}x.png"
    rsvg-convert -w "$px" -h "$px" "$SRC/app-icon.svg" -o "$XC/AppIcon.appiconset/$name"
    images+="${images:+,}
    { \"idiom\": \"mac\", \"size\": \"${pt}x${pt}\", \"scale\": \"${scale}x\", \"filename\": \"$name\" }"
  done
done
printf '{ "images": [%s\n  ],\n  "info": { "author": "xcode", "version": 1 } }\n' "$images" \
  > "$XC/AppIcon.appiconset/Contents.json"

# Menu bar glyphs: vector PDFs rendered as template images
for s in off on; do
  set_dir="$XC/Menu$(tr '[:lower:]' '[:upper:]' <<< "${s:0:1}")${s:1}.imageset"
  rsvg-convert -f pdf "$SRC/menu-$s.svg" -o "$set_dir/menu-$s.pdf"
  cat > "$set_dir/Contents.json" <<JSON
{
  "images": [ { "idiom": "universal", "filename": "menu-$s.pdf" } ],
  "info": { "author": "xcode", "version": 1 },
  "properties": { "template-rendering-intent": "template", "preserves-vector-representation": true }
}
JSON
done

cp "$SRC/app-icon.svg" docs/images/logo.svg
echo "icons written to $XC and docs/images/logo.svg"
