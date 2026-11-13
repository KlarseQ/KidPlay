#!/usr/bin/env bash
# Build KidPlay.app and zip it for GitHub Releases.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${1:-1.0.0}"
DIST="$ROOT/dist"
STAGE="$DIST/stage"
APP_NAME="KidPlay.app"
ZIP_NAME="KidPlay-${VERSION}-macos.zip"

rm -rf "$DIST"
mkdir -p "$STAGE"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/KidPlay"

CONTENTS="$STAGE/$APP_NAME/Contents"
MACOS="$CONTENTS/MacOS"
mkdir -p "$MACOS"
cp "$BIN" "$MACOS/KidPlay"
chmod +x "$MACOS/KidPlay"

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>KidPlay</string>
  <key>CFBundleIdentifier</key>
  <string>xyz.klarseq.KidPlay</string>
  <key>CFBundleName</key>
  <string>KidPlay</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - --identifier "xyz.klarseq.KidPlay" "$STAGE/$APP_NAME"
xattr -cr "$STAGE/$APP_NAME" 2>/dev/null || true

(
  cd "$STAGE"
  ditto -c -k --keepParent "$APP_NAME" "$DIST/$ZIP_NAME"
)

# Also refresh local Applications install
APP_DIR="${HOME}/Applications"
mkdir -p "$APP_DIR"
ditto "$STAGE/$APP_NAME" "$APP_DIR/$APP_NAME"
codesign --force --deep --sign - --identifier "xyz.klarseq.KidPlay" "$APP_DIR/$APP_NAME" 2>/dev/null || true

echo "Release zip: $DIST/$ZIP_NAME"
ls -lh "$DIST/$ZIP_NAME"
