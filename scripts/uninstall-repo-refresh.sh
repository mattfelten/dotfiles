#!/usr/bin/env bash
# Uninstall the launchd agent that fast-forwards default branches to origin.
set -uo pipefail

LABEL="com.mattfelten.repo-refresh"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

launchctl unload "$PLIST" 2>/dev/null || true
rm -f "$PLIST"

if launchctl list | grep -q "$LABEL"; then
  echo "WARNING: $LABEL is still loaded" >&2
  exit 1
else
  echo "Uninstalled: $LABEL"
fi
