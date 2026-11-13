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
  <string>1.1.0</string>
  <key>CFBundleVersion</key>
  <string>1.1.0</string>
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

# Re-sign in place with stable bundle identifier.
codesign --force --deep --sign - --identifier "xyz.klarseq.KidPlay" "$APP" 2>/dev/null || true
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

echo "Updated $APP"
echo "Launching (permissions are NOT re-prompted by the app on start)."
open "$APP"
