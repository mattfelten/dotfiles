#!/usr/bin/env bash
# Keep every checkout under a root in sync with its origin, on one timer.
#
# Two modes, chosen per repo:
#
#   push  — repos whose contents I edit directly and want persisted, so a lost
#           machine loses nothing: commit everything, rebase on origin, push.
#   pull  — checkouts of shared work: fast-forward the default branch only.
#           Never commits, never pushes, never rebases, never touches a dirty
#           tree, a feature branch, or a worktree.
#
# Pull mode is deliberately incapable of losing work. Where the default branch
# isn't checked out its ref is advanced with `git fetch origin main:main`, which
# git refuses unless it is a clean fast-forward.
#
# Usage: git-sync.sh [root]                 (default root: ~/Projects)
set -uo pipefail

ROOT="${1:-$HOME/Projects}"

# Repos that get push mode. Everything else discovered under ROOT is pull-only,
# which is the safe default for anything newly cloned.
PUSH_RE='/(dotfiles|ai-brain)$'

# The agent ticks every 10 minutes so push repos persist promptly, but pull-only
# repos are refreshed at most this often. Without this, a work checkout could get
# 80 commits swapped in under a running dev server every few minutes.
PULL_MIN_AGE="${PULL_MIN_AGE:-1500}"   # seconds (25 min); override to force a refresh

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*"; }

# Commit local changes, rebase onto origin, push. Mirrors the behaviour of the
# autosync agents this replaced.
sync_push_repo() {
  local repo="$1" branch committed=""

  git -C "$repo" add -A
  if ! git -C "$repo" diff --cached --quiet; then
    git -C "$repo" commit -q -m "autosync: $(date '+%Y-%m-%d %H:%M')" || true
    committed=1
  fi

  git -C "$repo" remote get-url origin >/dev/null 2>&1 || return 0
  branch="$(git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null || echo main)"
  git -C "$repo" pull --rebase --autostash -q origin "$branch" 2>/dev/null || true
  git -C "$repo" push -q origin HEAD 2>/dev/null || true

  [ -n "$committed" ] && log "$repo: committed + pushed ($branch)"
  return 0
}

# Fast-forward the default branch to origin. Touches nothing else.
refresh_pull_repo() {
  local repo="$1" def head behind fetch_head age

  git -C "$repo" remote get-url origin >/dev/null 2>&1 || return 0

  # Skip repos fetched recently enough — see PULL_MIN_AGE.
  fetch_head="$repo/.git/FETCH_HEAD"
  if [ -f "$fetch_head" ]; then
    age=$(( $(date +%s) - $(stat -f %m "$fetch_head" 2>/dev/null || echo 0) ))
    [ "$age" -lt "$PULL_MIN_AGE" ] && return 0
  fi

  if ! git -C "$repo" fetch --prune --quiet origin 2>/dev/null; then
    log "$repo: fetch failed"
    return 0
  fi

  def="$(git -C "$repo" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)"
  def="${def#origin/}"
  [ -n "$def" ] || def=main

  head="$(git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null)"

  if [ "$head" = "$def" ]; then
    behind="$(git -C "$repo" rev-list --count "HEAD..origin/$def" 2>/dev/null || echo 0)"
    [ "$behind" = "0" ] && return 0
    if [ -n "$(git -C "$repo" status --porcelain 2>/dev/null)" ]; then
      log "$repo: $def is $behind behind, working tree dirty, left alone"
      return 0
    fi
    if git -C "$repo" merge --ff-only --quiet "origin/$def" 2>/dev/null; then
      log "$repo: $def fast-forwarded $behind commits"
    else
      log "$repo: $def could not fast-forward (diverged from origin/$def)"
    fi
  else
    # Default branch isn't checked out here, so move its ref without a checkout.
    behind="$(git -C "$repo" rev-list --count "$def..origin/$def" 2>/dev/null || echo 0)"
    [ "$behind" = "0" ] && return 0
    if git -C "$repo" fetch --quiet origin "$def:$def" 2>/dev/null; then
      log "$repo: $def advanced $behind commits (on $head, not touched)"
    fi
  fi
  return 0
}

# Depth 3 covers <root>/<sphere>/<repo>/.git. Worktrees live deeper, under
# <repo>/.claude/worktrees/, and hold in-progress work — never touched.
while IFS= read -r gitdir; do
  repo="${gitdir%/.git}"
  if [[ "$repo" =~ $PUSH_RE ]]; then
    sync_push_repo "$repo"
  else
    refresh_pull_repo "$repo"
  fi
done < <(find "$ROOT" -maxdepth 3 -name .git -not -path "*/.claude/worktrees/*" 2>/dev/null)
