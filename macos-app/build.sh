#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCES_DIR="$SCRIPT_DIR/Sources"
RESOURCES_DIR="$SCRIPT_DIR/Resources"
BUILD_DIR="$SCRIPT_DIR/build"
APP_NAME="BT Battery.app"
APP_DIR="$BUILD_DIR/$APP_NAME"
BINARY_NAME="bt-battery"

echo "Building BT Battery..."

# Clean previous build
rm -rf "$APP_DIR"

# Create .app bundle structure
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy Info.plist
cp "$RESOURCES_DIR/Info.plist" "$APP_DIR/Contents/Info.plist"

# Compile Swift sources
swiftc \
    -o "$APP_DIR/Contents/MacOS/$BINARY_NAME" \
    -framework IOBluetooth \
    -framework Foundation \
    -framework Cocoa \
    -framework UserNotifications \
    -framework SwiftUI \
    "$SOURCES_DIR/BluetoothDevice.swift" \
    "$SOURCES_DIR/Settings.swift" \
    "$SOURCES_DIR/NotificationManager.swift" \
    "$SOURCES_DIR/BluetoothMonitor.swift" \
    "$SOURCES_DIR/SettingsView.swift" \
    "$SOURCES_DIR/App.swift" \
    -O

# Codesign with developer identity (persists TCC permissions across rebuilds)
# Falls back to ad-hoc if no developer identity is found
IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | grep "Apple Development" | head -1 | sed 's/.*"\(.*\)"/\1/')
if [ -n "$IDENTITY" ]; then
    codesign --force --sign "$IDENTITY" "$APP_DIR"
    echo "Signed with: $IDENTITY"
else
    codesign --force --sign - "$APP_DIR"
    echo "Signed with ad-hoc (no developer identity found)"
fi

echo "Build complete: $APP_DIR"
