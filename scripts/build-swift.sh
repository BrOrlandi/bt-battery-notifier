#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SWIFT_SRC="$PROJECT_DIR/swift/bt_battery.swift"
SWIFT_BIN="$PROJECT_DIR/swift/bt_battery"

echo "Compiling bt_battery.swift..."
swiftc "$SWIFT_SRC" \
  -framework IOBluetooth \
  -framework Foundation \
  -o "$SWIFT_BIN"

echo "Build successful: $SWIFT_BIN"
