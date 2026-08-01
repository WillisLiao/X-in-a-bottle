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
BUNDLE="com.lull.elvle"

DEVICE="${1:-}"
if [[ -z "$DEVICE" ]]; then
  # Column-position parsing breaks the moment a device's name has a space in
  # it - "iPhone的 廖虹凱" is two fields, not one, and shifts everything after
  # it. The identifier is a UUID and nothing else on the line looks like one,
  # so pull it out by shape instead of by position.
  DEVICE=$(xcrun devicectl list devices 2>/dev/null \
    | grep -E "connected" | grep "iPhone" \
    | grep -oE "[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}" \
    | head -1)
fi

if [[ -z "$DEVICE" ]]; then
  echo "No connected iPhone found. Plug one in, or pass its identifier." >&2
  exit 1
fi

echo "==> Exporting Xcode project"
rm -rf "$OUT"
mkdir -p "$OUT"
"$GODOT" --headless --path "$HERE" --export-debug "iOS" "$OUT/Elvle.xcodeproj" 2>&1 \
  | grep -viE "^\[|godot engine" || true

echo "==> Building"
xcodebuild -project "$OUT/Elvle.xcodeproj" -scheme Elvle \
  -sdk iphoneos -destination "platform=iOS,id=$DEVICE" \
  -configuration Debug -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM" PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE" \
  build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED" | head -20

# "*Debug-iphoneos*" alone also matches the archive intermediate under
# ArchiveIntermediates/.../BuildProductsPath/Debug-iphoneos/, which looks
# installable and is not - devicectl rejects it with a bare "not a type it
# recognizes" error. The one actually meant to be installed sits under
# Build/Products/Debug-iphoneos/.
APP=$(find ~/Library/Developer/Xcode/DerivedData -name "Elvle.app" \
  -path "*/Build/Products/Debug-iphoneos/*" -not -path "*Index.noindex*" \
  -newermt "-5 minutes" 2>/dev/null | head -1)

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
