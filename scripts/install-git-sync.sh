#!/usr/bin/env bash
# Install the single launchd agent that keeps every checkout under a root in sync,
# and migrate off the per-repo agents it replaces. Idempotent — safe to re-run.
# Machine-agnostic: derives paths from $HOME and this script's location.
#     ~/Projects/personal/dotfiles/scripts/install-git-sync.sh [root]
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="${1:-$HOME/Projects}"
LABEL="com.mattfelten.git-sync"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

# --- migrate off the agents this one replaces --------------------------------
# Removed before the new agent is loaded so the two never run against the same
# repo at once.
for legacy in com.mattfelten.dotfiles-autosync \
              com.mattfelten.aibrain-autosync \
              com.mattfelten.repo-refresh; do
  legacy_plist="$HOME/Library/LaunchAgents/$legacy.plist"
  if [ -e "$legacy_plist" ]; then
    launchctl unload "$legacy_plist" 2>/dev/null || true
    rm -f "$legacy_plist"
    echo "Removed legacy agent: $legacy"
  fi
done

# Now unreferenced. Tracked in git in both repos, so recoverable.
for legacy_script in "$REPO/scripts/autosync.sh" \
                     "$REPO/scripts/install-autosync.sh" \
                     "$REPO/scripts/uninstall-autosync.sh" \
                     "$REPO/scripts/repo-refresh.sh" \
                     "$REPO/scripts/install-repo-refresh.sh" \
                     "$REPO/scripts/uninstall-repo-refresh.sh" \
                     "$HOME/Projects/personal/ai-brain/scripts/autosync.sh" \
                     "$HOME/Projects/personal/ai-brain/scripts/install-autosync.sh"; do
  if [ -e "$legacy_script" ]; then
    rm -f "$legacy_script"
    echo "Removed superseded script: ${legacy_script#$HOME/}"
  fi
done

# --- install ----------------------------------------------------------------
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
        <string>$REPO/scripts/git-sync.sh</string>
        <string>$ROOT</string>
    </array>
    <key>StartInterval</key>
    <integer>600</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$HOME/Library/Logs/git-sync.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/Library/Logs/git-sync.log</string>
</dict>
</plist>
EOF

launchctl unload "$PLIST" 2>/dev/null || true
launchctl load -w "$PLIST" 2>/dev/null || true

echo "Installed: $LABEL"
echo "  root:  $ROOT"
echo "  log:   $HOME/Library/Logs/git-sync.log"
if launchctl print "gui/$(id -u)/$LABEL" >/dev/null 2>&1; then
  echo "  status: loaded and running"
else
  # A plist in ~/Library/LaunchAgents loads automatically at next login even if
  # `launchctl load` couldn't reach the GUI session domain right now.
  echo "  status: plist written; loads at next login, or run:"
  echo "          launchctl load -w \"$PLIST\""
fi
