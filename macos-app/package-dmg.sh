#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
APP_NAME="BT Battery Notifier.app"
APP_DIR="$BUILD_DIR/$APP_NAME"
VERSION="1.0.0"
DMG_NAME="BT-Battery-Notifier-${VERSION}.dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"
TEMP_DIR="$BUILD_DIR/dmg-staging"

echo "=== Packaging BT Battery Notifier $VERSION ==="

# Step 1: Build the release .app
echo "Building release..."
bash "$SCRIPT_DIR/build.sh" --release

if [ ! -d "$APP_DIR" ]; then
    echo "Error: $APP_DIR not found after build"
    exit 1
fi

# Step 2: Create staging directory with .app and /Applications symlink
echo "Preparing DMG contents..."
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"
cp -R "$APP_DIR" "$TEMP_DIR/"
ln -s /Applications "$TEMP_DIR/Applications"

# Step 3: Create DMG
echo "Creating DMG..."
rm -f "$DMG_PATH"
hdiutil create \
    -volname "BT Battery Notifier" \
    -srcfolder "$TEMP_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

# Step 4: Clean up
rm -rf "$TEMP_DIR"

echo ""
echo "=== DMG created: $DMG_PATH ==="
echo "Size: $(du -h "$DMG_PATH" | cut -f1)"
