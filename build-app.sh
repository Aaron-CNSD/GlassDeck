#!/bin/bash
# Build GlassDeck.app using Swift Package Manager (no Xcode required).
# Produces a runnable .app bundle in ./build/.

set -euo pipefail

cd "$(dirname "$0")"

echo "==> Building GlassDeck..."
swift build -c release

APP="build/GlassDeck.app"
BIN=".build/release/GlassDeck"

echo "==> Assembling $APP ..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/GlassDeck"

# Info.plist
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>GlassDeck</string>
    <key>CFBundleDisplayName</key>
    <string>GlassDeck</string>
    <key>CFBundleIdentifier</key>
    <string>com.glassdeck.app</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>GlassDeck</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# Copy app icon if present
if [ -f "Resources/AppIcon.appiconset/icon_1024.png" ]; then
    mkdir -p "$APP/Contents/Resources/AppIcon.appiconset"
    cp "Resources/AppIcon.appiconset/icon_1024.png" "$APP/Contents/Resources/AppIcon.appiconset/"
    cp "Resources/AppIcon.appiconset/Contents.json" "$APP/Contents/Resources/AppIcon.appiconset/"
fi

echo "==> Done: $APP"
echo "    Run with:  open $APP"
