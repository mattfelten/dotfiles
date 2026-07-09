#!/usr/bin/env bash
# Install the launchd agent that auto-syncs this dotfiles repo to git every 10 minutes.
# Machine-agnostic: derives paths from $HOME and this script's location, so it works
# on any Mac regardless of username. Run it once per machine:
#     ~/Projects/personal/dotfiles/scripts/install-autosync.sh
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
LABEL="com.mattfelten.dotfiles-autosync"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$REPO/scripts/autosync.sh</string>
        <string>$REPO</string>
    </array>
    <key>StartInterval</key>
    <integer>600</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$HOME/Library/Logs/dotfiles-autosync.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/Library/Logs/dotfiles-autosync.log</string>
</dict>
</plist>
EOF

launchctl unload "$PLIST" 2>/dev/null || true
launchctl load -w "$PLIST"

if launchctl list | grep -q "$LABEL"; then
  echo "Installed and loaded: $LABEL"
  echo "  repo:  $REPO"
  echo "  log:   $HOME/Library/Logs/dotfiles-autosync.log"
else
  echo "ERROR: agent did not load" >&2
  exit 1
fi
