#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="BT Battery.app"
BUILD_DIR="$SCRIPT_DIR/build"
INSTALL_DIR="/Applications"

# Build with release signing (required for TCC permissions like Bluetooth)
bash "$SCRIPT_DIR/build.sh" --release

# Kill existing instance if running
pkill -f "BT Battery" 2>/dev/null || true

# Copy to /Applications
echo "Installing to $INSTALL_DIR..."
rm -rf "$INSTALL_DIR/$APP_NAME"
cp -R "$BUILD_DIR/$APP_NAME" "$INSTALL_DIR/$APP_NAME"

# Launch the app
echo "Launching BT Battery..."
open "$INSTALL_DIR/$APP_NAME"

echo "Done! BT Battery is running in the menubar."
echo "To launch at login, enable it in the app settings."
