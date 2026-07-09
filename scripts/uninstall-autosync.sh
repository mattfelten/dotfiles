#!/usr/bin/env bash
# Uninstall the launchd agent that auto-syncs this dotfiles repo to git.
# Run once per machine, or via `npm run unsymlink`.
set -uo pipefail

LABEL="com.mattfelten.dotfiles-autosync"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

launchctl unload "$PLIST" 2>/dev/null || true
rm -f "$PLIST"

if launchctl list | grep -q "$LABEL"; then
  echo "WARNING: $LABEL is still loaded" >&2
  exit 1
else
  echo "Uninstalled: $LABEL"
fi
