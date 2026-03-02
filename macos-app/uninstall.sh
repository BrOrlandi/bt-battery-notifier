#!/bin/bash
set -e

APP_NAME="BT Battery.app"
INSTALL_DIR="/Applications"

echo "Stopping BT Battery..."
pkill -f "BT Battery" 2>/dev/null || true

echo "Removing from $INSTALL_DIR..."
rm -rf "$INSTALL_DIR/$APP_NAME"

echo "Uninstalled BT Battery."
