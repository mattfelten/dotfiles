#!/usr/bin/env bash
# Keep the default branch of every checkout under a root current with origin.
#
# Deliberately incapable of losing work:
#   - fast-forward only, never rebase, never merge divergent history
#   - skips any repo whose working tree is dirty
#   - never touches worktrees, feature branches, or anything you have checked out
#
# When the default branch is checked out it is fast-forwarded. When it is not,
# the local ref is advanced directly (git fetch origin main:main), which git
# refuses unless it is a clean fast-forward.
#
# Usage: repo-refresh.sh [root]          (default root: ~/Projects)
set -uo pipefail

ROOT="${1:-$HOME/Projects}"

# These sync themselves via their own autosync agent (which rebases and pushes);
# refreshing them here too would just race with it.
EXCLUDE_RE='/(dotfiles|ai-brain)$'

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*"; }

# Depth 3 covers <root>/<sphere>/<repo>/.git. Worktrees live under
# <repo>/.claude/worktrees/ and are skipped: they hold in-progress work.
while IFS= read -r gitdir; do
  repo="${gitdir%/.git}"
  [[ "$repo" =~ $EXCLUDE_RE ]] && continue
  git -C "$repo" remote get-url origin >/dev/null 2>&1 || continue

  if ! git -C "$repo" fetch --prune --quiet origin 2>/dev/null; then
    log "$repo: fetch failed"
    continue
  fi

  def="$(git -C "$repo" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)"
  def="${def#origin/}"
  [ -n "$def" ] || def=main

  head="$(git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null)"

  if [ "$head" = "$def" ]; then
    behind="$(git -C "$repo" rev-list --count "HEAD..origin/$def" 2>/dev/null || echo 0)"
    [ "$behind" = "0" ] && continue
    if [ -n "$(git -C "$repo" status --porcelain 2>/dev/null)" ]; then
      log "$repo: $def is $behind behind, working tree dirty, left alone"
      continue
    fi
    if git -C "$repo" merge --ff-only --quiet "origin/$def" 2>/dev/null; then
      log "$repo: $def fast-forwarded $behind commits"
    else
      log "$repo: $def could not fast-forward (diverged from origin/$def)"
    fi
  else
    # Default branch isn't checked out here, so move its ref without a checkout.
    # Fails harmlessly if it isn't a fast-forward or it's checked out elsewhere.
    behind="$(git -C "$repo" rev-list --count "$def..origin/$def" 2>/dev/null || echo 0)"
    [ "$behind" = "0" ] && continue
    if git -C "$repo" fetch --quiet origin "$def:$def" 2>/dev/null; then
      log "$repo: $def advanced $behind commits (on $head, not touched)"
    fi
  fi
done < <(find "$ROOT" -maxdepth 3 -name .git -not -path "*/.claude/worktrees/*" 2>/dev/null)
