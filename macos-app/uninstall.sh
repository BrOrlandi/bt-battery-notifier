#!/bin/bash
set -e

APP_NAME="BT Battery Notifier.app"
INSTALL_DIR="/Applications"

echo "Stopping BT Battery Notifier..."
pkill -f "BT Battery Notifier" 2>/dev/null || true

echo "Removing from $INSTALL_DIR..."
rm -rf "$INSTALL_DIR/$APP_NAME"

echo "Uninstalled BT Battery Notifier."
