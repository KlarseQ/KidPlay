#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

swift build -c release

BIN="$(swift build -c release --show-bin-path)/KidPlay"

# Stable install path. Do NOT wipe the .app every run — that breaks TCC grants.
APP_DIR="${HOME}/Applications"
APP="${APP_DIR}/KidPlay.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"

mkdir -p "$MACOS"

# Update binary in place (keeps bundle identity / TCC association better than rm -rf).
cp "$BIN" "$MACOS/KidPlay"
chmod +x "$MACOS/KidPlay"

if [[ ! -f "$CONTENTS/Info.plist" ]]; then
  cat > "$CONTENTS/Info.plist" <<'PLIST'
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
  <string>1.2.1</string>
  <key>CFBundleVersion</key>
  <string>1.2.1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST
fi

# Skip force re-sign — ad-hoc --force changes CDHash and drops TCC grants.
# First-time installs may need a one-shot: codesign -s - --identifier xyz.klarseq.KidPlay "$APP"
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

# Keep Info.plist version in sync when the file already existed.
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 1.2.1" "$CONTENTS/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion 1.2.1" "$CONTENTS/Info.plist" 2>/dev/null || true

echo "Updated $APP"
echo "Launching (permissions are NOT re-prompted by the app on start)."
open "$APP"
