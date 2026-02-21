#!/bin/bash
set -e

# build-dmg.sh — builds Islet.app in Release mode and packages it as a DMG.
# Usage: ./scripts/build-dmg.sh [--sign]
#   --sign   Ad-hoc code-sign the app before packaging (recommended)

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="Islet"
PROJECT="$REPO_ROOT/Islet.xcodeproj"
OUTPUT_DIR="$REPO_ROOT/dist"
DMG_NAME="Islet"
STAGING="/tmp/islet-dmg-staging"

SIGN=false
for arg in "$@"; do
  [[ "$arg" == "--sign" ]] && SIGN=true
done

echo "==> Building $SCHEME (Release)…"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$REPO_ROOT/.build/xcode" \
  build \
  2>&1 | grep -E "(error:|warning:|BUILD |Linking)"

APP_PATH=$(find "$REPO_ROOT/.build/xcode/Build/Products/Release" -name "Islet.app" -maxdepth 1 2>/dev/null | head -1)

if [[ -z "$APP_PATH" ]]; then
  echo "ERROR: Islet.app not found after build. Check build output above."
  exit 1
fi

echo "==> App built at: $APP_PATH"

if $SIGN; then
  echo "==> Ad-hoc signing…"
  codesign --deep --force --sign - "$APP_PATH"
  echo "    Signed."
fi

echo "==> Staging DMG contents…"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

mkdir -p "$OUTPUT_DIR"
DMG_PATH="$OUTPUT_DIR/${DMG_NAME}.dmg"

echo "==> Creating DMG…"
hdiutil create \
  -volname "$DMG_NAME" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDZO \
  -o "$DMG_PATH"

rm -rf "$STAGING"

echo ""
echo "✓ Done: $DMG_PATH"
