#!/usr/bin/env bash
# Uninstall the git-sync launchd agent. Leaves every repo exactly as it is.
set -uo pipefail

LABEL="com.mattfelten.git-sync"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

launchctl unload "$PLIST" 2>/dev/null || true
rm -f "$PLIST"

if launchctl print "gui/$(id -u)/$LABEL" >/dev/null 2>&1; then
  echo "WARNING: $LABEL is still loaded" >&2
  exit 1
else
  echo "Uninstalled: $LABEL"
fi
