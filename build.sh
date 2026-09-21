#!/bin/bash

set -euo pipefail

APP_NAME="NetSpeed"
BUILD_DIR=".build/release"
APP_DIR="${APP_NAME}.app"

echo "Building ${APP_NAME}..."

swift build -c release

rm -rf "$APP_DIR"

mkdir -p \
    "$APP_DIR/Contents/MacOS" \
    "$APP_DIR/Contents/Resources"

cp \
    "$BUILD_DIR/$APP_NAME" \
    "$APP_DIR/Contents/MacOS/$APP_NAME"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>NetSpeed</string>

    <key>CFBundleDisplayName</key>
    <string>NetSpeed</string>

    <key>CFBundleIdentifier</key>
    <string>local.netspeed</string>

    <key>CFBundleExecutable</key>
    <string>NetSpeed</string>

    <key>CFBundlePackageType</key>
    <string>APPL</string>

    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>

    <key>CFBundleVersion</key>
    <string>1</string>

    <key>LSMinimumSystemVersion</key>
    <string>26.0</string>

    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

echo
echo "Built: ${APP_DIR}"
echo
echo "Run with:"
echo "  open ${APP_DIR}"