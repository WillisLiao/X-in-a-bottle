#!/usr/bin/env bash
# Export the Godot project to an Xcode project, build it, and install it on the
# connected iPhone.
#
# Godot's iOS export does not produce an .ipa directly - it produces an Xcode
# project, which is then built the same way the native apps in this repo are.
# That is why this script exists rather than a single godot --export call.

set -euo pipefail

GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$HERE/build/ios"
TEAM="45MSS5RXML"
BUNDLE="com.lull.bottle3d"

DEVICE="${1:-}"
if [[ -z "$DEVICE" ]]; then
  DEVICE=$(xcrun devicectl list devices 2>/dev/null \
    | awk '/connected/ && /iPhone/ {print $(NF-3); exit}')
fi

if [[ -z "$DEVICE" ]]; then
  echo "No connected iPhone found. Plug one in, or pass its identifier." >&2
  exit 1
fi

echo "==> Exporting Xcode project"
rm -rf "$OUT"
mkdir -p "$OUT"
"$GODOT" --headless --path "$HERE" --export-debug "iOS" "$OUT/Bottle.xcodeproj" 2>&1 \
  | grep -viE "^\[|godot engine" || true

echo "==> Building"
xcodebuild -project "$OUT/Bottle.xcodeproj" -scheme Bottle \
  -sdk iphoneos -destination "platform=iOS,id=$DEVICE" \
  -configuration Debug -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM" PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE" \
  build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED" | head -20

APP=$(find ~/Library/Developer/Xcode/DerivedData -name "Bottle.app" \
  -path "*Debug-iphoneos*" -not -path "*Index.noindex*" -newermt "-5 minutes" \
  2>/dev/null | head -1)

if [[ -z "$APP" ]]; then
  echo "Could not find the built app bundle." >&2
  exit 1
fi

echo "==> Installing $APP"
xcrun devicectl device install app --device "$DEVICE" "$APP" \
  2>&1 | grep -iE "error|installed|bundleID"

echo "==> Launching"
xcrun devicectl device process launch --device "$DEVICE" "$BUNDLE" \
  2>&1 | grep -iE "error|Launched" || true
