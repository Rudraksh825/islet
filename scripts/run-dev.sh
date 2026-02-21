#!/bin/bash
set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DEST="/Applications/Islet.app"
CONTENTS="$APP_DEST/Contents"
RESOURCE_BUNDLE="$REPO_ROOT/.build/debug/Islet_Islet.bundle"

echo "==> Killing running instance..."
pkill -x Islet 2>/dev/null || true
sleep 0.3

echo "==> Building..."
swift build --package-path "$REPO_ROOT" 2>&1 | grep -E "(error:|warning:|Build complete)"

echo "==> Installing to $APP_DEST..."
rm -rf "$APP_DEST"
mkdir -p "$CONTENTS/MacOS"
mkdir -p "$CONTENTS/Resources"

cp "$REPO_ROOT/.build/debug/Islet"      "$CONTENTS/MacOS/Islet"
cp "$REPO_ROOT/Islet/Info.plist"         "$CONTENTS/Info.plist"
cp "$REPO_ROOT/Islet/menubar_icon.png"   "$CONTENTS/Resources/menubar_icon.png"

if [ -d "$RESOURCE_BUNDLE" ]; then
    cp -R "$RESOURCE_BUNDLE" "$CONTENTS/Resources/"
fi

# Strip quarantine so macOS doesn't block it
xattr -cr "$APP_DEST" 2>/dev/null || true

echo "==> Launching..."
open "$APP_DEST"
echo "    Done. Check your menu bar."
