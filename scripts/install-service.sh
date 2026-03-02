#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LABEL="com.brunoorlandi.notify-bt-battery"
PLIST_SRC="$PROJECT_DIR/$LABEL.plist"
PLIST_DST="$HOME/Library/LaunchAgents/$LABEL.plist"

# Build Swift binary
echo "Building Swift binary..."
bash "$SCRIPT_DIR/build-swift.sh"

# Resolve node path
NODE_PATH="$(which node)"
if [ -z "$NODE_PATH" ]; then
  echo "Error: node not found in PATH"
  exit 1
fi
echo "Using node: $NODE_PATH"

# Create logs directory
mkdir -p "$PROJECT_DIR/logs"

# Generate plist with resolved paths
sed -e "s|__NODE_PATH__|$NODE_PATH|g" \
    -e "s|__PROJECT_DIR__|$PROJECT_DIR|g" \
    "$PLIST_SRC" > "$PLIST_DST"

# Unload if already loaded
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true

# Load service
launchctl bootstrap "gui/$(id -u)" "$PLIST_DST"

echo "Service installed and started: $LABEL"
echo "Logs: $PROJECT_DIR/logs/"
