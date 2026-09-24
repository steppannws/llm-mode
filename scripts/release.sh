#!/usr/bin/env bash
# scripts/release.sh — build LLMMode.app, sign (Developer ID + hardened runtime),
# notarize, staple, and zip it into build/.
# usage: scripts/release.sh [--no-notarize]
#   SIGN_IDENTITY   codesign identity   (default: "Developer ID Application")
#   NOTARY_PROFILE  notarytool profile  (default: llm-mode-notary, see README)
set -euo pipefail
cd "$(dirname "$0")/.."

IDENTITY="${SIGN_IDENTITY:-Developer ID Application}"
PROFILE="${NOTARY_PROFILE:-llm-mode-notary}"
NOTARIZE=1
for a in "$@"; do
  case "$a" in
    --no-notarize) NOTARIZE=0 ;;
    *) echo "usage: scripts/release.sh [--no-notarize]" >&2; exit 2 ;;
  esac
done

OUT=build
APP="$OUT/dd/Build/Products/Release/LLMMode.app"
VERSION=$(git describe --tags --always --dirty)
ZIP="$OUT/LLMMode-$VERSION.zip"

step() { printf '\n==> %s\n' "$*"; }

step "generate project"
(cd app && xcodegen --quiet)

step "build (unsigned)"
rm -rf "$OUT"; mkdir -p "$OUT"
xcodebuild -project app/LLMMode.xcodeproj -scheme LLMMode -configuration Release \
  -destination "generic/platform=macOS" -derivedDataPath "$OUT/dd" CODE_SIGNING_ALLOWED=NO -quiet build

step "sign: $IDENTITY"
codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP"

if [[ $NOTARIZE -eq 1 ]]; then
  step "notarize (profile: $PROFILE)"
  ditto -c -k --keepParent "$APP" "$OUT/notarize.zip"
  xcrun notarytool submit "$OUT/notarize.zip" --keychain-profile "$PROFILE" --wait
  rm "$OUT/notarize.zip"

  step "staple"
  xcrun stapler staple "$APP"
  spctl --assess --type execute --verbose=2 "$APP"
fi

step "package"
ditto -c -k --keepParent "$APP" "$ZIP"
echo "$ZIP"
