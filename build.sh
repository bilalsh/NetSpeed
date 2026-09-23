#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Copyright (C) 2026 Neo
#
# This file is part of NetSpeed, distributed under the terms of the
# GNU General Public License version 3 or later. See LICENSE.
#
# Build NetSpeed.app
#
#   ./build.sh            build NetSpeed.app in the repo root
#   ./build.sh --install  also copy it to /Applications
#
set -euo pipefail

APP_NAME="NetSpeed"
BUNDLE_ID="local.netspeed"
VERSION="0.2.2"
BUILD_NUMBER="4"

BUILD_DIR=".build/release"
APP_DIR="${APP_NAME}.app"
ICONSET="Resources/AppIcon.iconset"

INSTALL=0
[[ "${1:-}" == "--install" ]] && INSTALL=1

if [[ "$(uname)" != "Darwin" ]]; then
    echo "error: this script must be run on macOS." >&2
    exit 1
fi

echo "Building ${APP_NAME}..."
swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"

# --- App icon ---------------------------------------------------------------
if [[ -d "$ICONSET" ]]; then
    echo "Creating AppIcon.icns..."
    iconutil -c icns "$ICONSET" -o "$APP_DIR/Contents/Resources/AppIcon.icns"
else
    echo "warning: $ICONSET not found; app will use the generic icon." >&2
fi

# --- Info.plist -------------------------------------------------------------
cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>

    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>

    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>

    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>

    <key>CFBundleIconFile</key>
    <string>AppIcon</string>

    <key>CFBundlePackageType</key>
    <string>APPL</string>

    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>

    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>

    <key>LSMinimumSystemVersion</key>
    <string>26.0</string>

    <key>LSUIElement</key>
    <true/>

    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# --- Sign -------------------------------------------------------------------
# Ad-hoc signature. Login-item registration (SMAppService) is sensitive to
# bundle signing, and an unsigned bundle is more likely to be rejected.
echo "Signing (ad-hoc)..."
codesign --force --deep --sign - "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

# --- Install ----------------------------------------------------------------
# Launch-at-login registers the bundle's *path*. Registering from a build
# directory that later moves or is deleted leaves a dead login item, so
# installing to /Applications first is recommended.
if [[ "$INSTALL" -eq 1 ]]; then
    echo "Installing to /Applications..."
    pkill -x "$APP_NAME" 2>/dev/null || true
    rm -rf "/Applications/$APP_DIR"
    cp -R "$APP_DIR" "/Applications/$APP_DIR"
    # Nudge Finder/Dock to refresh the icon.
    touch "/Applications/$APP_DIR"
    echo
    echo "Installed: /Applications/${APP_DIR}"
    echo "Run with:  open /Applications/${APP_DIR}"
else
    echo
    echo "Built: ${APP_DIR}"
    echo
    echo "Run with:"
    echo "  open ${APP_DIR}"
    echo
    echo "Tip: run './build.sh --install' to put it in /Applications so"
    echo "launch-at-login points at a stable location."
fi
