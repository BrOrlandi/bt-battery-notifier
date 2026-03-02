#!/bin/bash
set -e

LABEL="com.brunoorlandi.notify-bt-battery"
PLIST_DST="$HOME/Library/LaunchAgents/$LABEL.plist"

# Unload service
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true

# Remove plist
rm -f "$PLIST_DST"

echo "Service uninstalled: $LABEL"
