#!/usr/bin/env bash
# Commit + push each given git repo if it has changes. Safe to run on a timer (launchd).
# Usage: autosync.sh /path/to/repo [/path/to/another-repo ...]
set -uo pipefail

for repo in "$@"; do
  [ -d "$repo/.git" ] || continue
  cd "$repo" || continue

  git add -A
  if ! git diff --cached --quiet; then
    git commit -q -m "autosync: $(date '+%Y-%m-%d %H:%M')" || true
  fi

  # Only touch the remote if one is configured.
  if git remote get-url origin >/dev/null 2>&1; then
    branch="$(git symbolic-ref --short HEAD 2>/dev/null || echo main)"
    git pull --rebase --autostash -q origin "$branch" 2>/dev/null || true
    git push -q origin HEAD 2>/dev/null || true
  fi
done
