#!/usr/bin/env bash
# Install the launchd agent that fast-forwards every checkout's default branch
# to origin every 30 minutes. Machine-agnostic: derives paths from $HOME and this
# script's location. Run it once per machine:
#     ~/Projects/personal/dotfiles/scripts/install-repo-refresh.sh [root]
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="${1:-$HOME/Projects}"
LABEL="com.mattfelten.repo-refresh"
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
        <string>$REPO/scripts/repo-refresh.sh</string>
        <string>$ROOT</string>
    </array>
    <key>StartInterval</key>
    <integer>1800</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$HOME/Library/Logs/repo-refresh.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/Library/Logs/repo-refresh.log</string>
</dict>
</plist>
EOF

launchctl unload "$PLIST" 2>/dev/null || true
launchctl load -w "$PLIST" 2>/dev/null || true

echo "Installed: $LABEL"
echo "  root:  $ROOT"
echo "  log:   $HOME/Library/Logs/repo-refresh.log"
if launchctl list | grep -q "$LABEL"; then
  echo "  status: loaded and running"
else
  # A plist in ~/Library/LaunchAgents loads automatically at next login even if
  # `launchctl load` couldn't reach the GUI session domain right now.
  echo "  status: plist written; loads at next login, or run:"
  echo "          launchctl load -w \"$PLIST\""
fi
