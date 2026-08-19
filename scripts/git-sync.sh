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

# launchd hands over a minimal PATH that omits the homebrew prefix, but the GitLab
# credential helper is `!glab auth git-credential` — without glab on PATH every
# fetch against gitlab.com fails auth. Both prefixes listed so this works on the
# Intel Mac too.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

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
  local repo="$1" gitdir branch committed="" ahead marker

  gitdir="$(git -C "$repo" rev-parse --absolute-git-dir 2>/dev/null)" || return 0

  # Never touch a repo mid-operation. `add -A` during a conflicted rebase or
  # merge commits the conflict markers themselves and buries the operation.
  for marker in rebase-merge rebase-apply MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD BISECT_LOG; do
    if [ -e "$gitdir/$marker" ]; then
      log "$repo: $marker present (git operation in progress), left alone"
      return 0
    fi
  done

  # Detached HEAD has no branch to push to. Committing here strands the work in a
  # commit no branch can reach — recoverable only from the reflog, until it is
  # garbage-collected — while `push origin HEAD` fails outright.
  branch="$(git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null)" || branch=""
  if [ -z "$branch" ]; then
    log "$repo: detached HEAD, left alone"
    return 0
  fi

  git -C "$repo" add -A
  if ! git -C "$repo" diff --cached --quiet; then
    git -C "$repo" commit -q -m "autosync: $(date '+%Y-%m-%d %H:%M')" || true
    committed=1
  fi

  git -C "$repo" remote get-url origin >/dev/null 2>&1 || return 0
  git -C "$repo" pull --rebase --autostash -q origin "$branch" 2>/dev/null || true

  if git -C "$repo" push -q origin HEAD 2>/dev/null; then
    [ -n "$committed" ] && log "$repo: committed + pushed ($branch)"
  else
    # Only worth reporting if something is actually stranded locally, otherwise a
    # laptop that is merely offline would log on every tick.
    ahead="$(git -C "$repo" rev-list --count "@{upstream}..HEAD" 2>/dev/null || echo 0)"
    if [ -n "$committed" ] || [ "$ahead" != "0" ]; then
      log "$repo: push to $branch FAILED, $ahead local commit(s) not on origin"
    fi
  fi
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
    # Only *tracked* changes block the refresh. Untracked files (scratch notes,
    # .env.local, stray build output) accumulate in a working checkout and must not
    # stop it being kept current — git still refuses below if an incoming commit
    # would clobber one of them.
    if [ -n "$(git -C "$repo" status --porcelain --untracked-files=no 2>/dev/null)" ]; then
      log "$repo: $def is $behind behind, tracked files modified, left alone"
      return 0
    fi
    if git -C "$repo" merge --ff-only --quiet "origin/$def" 2>/dev/null; then
      log "$repo: $def fast-forwarded $behind commits"
    elif git -C "$repo" merge-base --is-ancestor HEAD "origin/$def" 2>/dev/null; then
      # HEAD really is an ancestor, so this was a working-tree obstruction rather
      # than divergence — say which, so the log isn't misleading.
      log "$repo: $def is $behind behind but a local file is in the way, left alone"
    else
      log "$repo: $def could not fast-forward, diverged from origin/$def"
    fi
  else
    # Default branch isn't checked out here, so move its ref without a checkout.
    behind="$(git -C "$repo" rev-list --count "$def..origin/$def" 2>/dev/null || echo 0)"
    [ "$behind" = "0" ] && return 0
    if git -C "$repo" fetch --quiet origin "$def:$def" 2>/dev/null; then
      log "$repo: $def advanced $behind commits (on ${head:-detached HEAD}, not touched)"
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
