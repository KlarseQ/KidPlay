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

# Refresh local Applications install IN PLACE (binary + plist only).
# Do not ditto/replace the whole .app or force re-sign — that drops TCC grants.
APP_DIR="${HOME}/Applications"
APP="${APP_DIR}/KidPlay.app"
mkdir -p "$APP/Contents/MacOS"
cp "$MACOS/KidPlay" "$APP/Contents/MacOS/KidPlay"
chmod +x "$APP/Contents/MacOS/KidPlay"
cp "$CONTENTS/Info.plist" "$APP/Contents/Info.plist"
xattr -cr "$APP" 2>/dev/null || true

echo "Release zip: $DIST/$ZIP_NAME"
echo "Local install (in-place): $APP"
ls -lh "$DIST/$ZIP_NAME"
