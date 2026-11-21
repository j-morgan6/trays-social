#!/usr/bin/env bash
#
# test-app-icons.sh — checks the iOS app icons and logo assets (W238).
#
# The checks:
#
#   - Each AppIcon PNG (default, dark, tinted) is 1024 x 1024 with no alpha
#     channel. An icon with alpha is an App Store rejection.
#   - The tinted icon is grayscale. iOS recolours it with the person's tint, so
#     a coloured source would come out muddy.
#   - The default and dark icons are not grayscale, so a tinted file copied
#     into the wrong slot is caught.
#   - The Logo-light and Logo-dark imagesets name an SVG that exists, and
#     keep vector data.
#
# Needs sips (macOS) and ImageMagick's magick.
# Run from anywhere: bash scripts/test-app-icons.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ASSETS="$REPO_ROOT/ios/TraysSocial/TraysSocial/Assets.xcassets"
ICONS="$ASSETS/AppIcon.appiconset"

failures=0
fail() { echo "FAIL: $1"; failures=$((failures + 1)); }
pass() { echo "ok:   $1"; }

# Mean saturation (0-1) of an image in HSL space; 0 means grayscale.
saturation() { magick "$1" -colorspace HSL -channel G -separate +channel -format '%[fx:mean]' info:; }

for name in app-icon app-icon-dark app-icon-tinted; do
  png="$ICONS/$name.png"
  if [ ! -f "$png" ]; then fail "$name.png is missing"; continue; fi

  alpha=$(sips -g hasAlpha "$png" | awk '/hasAlpha/ { print $2 }')
  width=$(sips -g pixelWidth "$png" | awk '/pixelWidth/ { print $2 }')
  height=$(sips -g pixelHeight "$png" | awk '/pixelHeight/ { print $2 }')
  [ "$alpha" = "no" ] && pass "$name.png has no alpha" || fail "$name.png has an alpha channel"
  [ "$width" = "1024" ] && [ "$height" = "1024" ] && pass "$name.png is 1024 x 1024" \
    || fail "$name.png is ${width} x ${height}, expected 1024 x 1024"

  sat=$(saturation "$png")
  if [ "$name" = "app-icon-tinted" ]; then
    awk -v s="$sat" 'BEGIN { exit !(s < 0.01) }' && pass "$name.png is grayscale" \
      || fail "$name.png has colour (mean saturation $sat); the tinted slot needs a grayscale source"
  else
    awk -v s="$sat" 'BEGIN { exit !(s >= 0.01) }' && pass "$name.png has colour" \
      || fail "$name.png is grayscale (mean saturation $sat); is the tinted icon in the wrong slot?"
  fi
done

for set_ in Logo-light Logo-dark; do
  contents="$ASSETS/$set_.imageset/Contents.json"
  if [ ! -f "$contents" ]; then fail "$set_.imageset is missing"; continue; fi
  file=$(plutil -extract images.0.filename raw -o - "$contents" 2>/dev/null || true)
  [ -n "$file" ] && [ -f "$ASSETS/$set_.imageset/$file" ] && pass "$set_ names an existing file ($file)" \
    || fail "$set_ names '$file', which is not in the imageset"
  vector=$(plutil -extract properties.preserves-vector-representation raw -o - "$contents" 2>/dev/null || true)
  [ "$vector" = "true" ] && pass "$set_ preserves vector data" || fail "$set_ does not preserve vector data"
done

# W273: the Browse category icons (Microsoft Fluent Emoji, Flat, MIT). iOS
# bundles one vector imageset per category key; web serves the same file from
# priv/static/images/categories. Both copies must be the identical, unmodified
# file, with Microsoft's LICENSE beside them.
CATEGORIES="$ASSETS/Categories"
WEB_CATEGORIES="$REPO_ROOT/priv/static/images/categories"
for dir in "$CATEGORIES" "$WEB_CATEGORIES"; do
  grep -q "Copyright (c) Microsoft Corporation" "$dir/LICENSE" 2>/dev/null \
    && pass "${dir#"$REPO_ROOT"/} keeps Microsoft's MIT LICENSE" \
    || fail "${dir#"$REPO_ROOT"/}/LICENSE is missing or is not Microsoft's MIT licence"
done
for key in quick_dinners chicken vegetarian beef pork baking; do
  contents="$CATEGORIES/$key.imageset/Contents.json"
  if [ ! -f "$contents" ]; then fail "$key.imageset is missing"; continue; fi
  file=$(plutil -extract images.0.filename raw -o - "$contents" 2>/dev/null || true)
  [ -n "$file" ] && [ -f "$CATEGORIES/$key.imageset/$file" ] && pass "$key names an existing file ($file)" \
    || fail "$key names '$file', which is not in the imageset"
  vector=$(plutil -extract properties.preserves-vector-representation raw -o - "$contents" 2>/dev/null || true)
  [ "$vector" = "true" ] && pass "$key preserves vector data" || fail "$key does not preserve vector data"
  cmp -s "$CATEGORIES/$key.imageset/$key.svg" "$WEB_CATEGORIES/$key.svg" \
    && pass "$key.svg is the same file on iOS and web" \
    || fail "$key.svg differs between iOS and web (or one is missing)"
done

if [ "$failures" -gt 0 ]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "All app icon checks passed"
