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

# A repo that can't be synced is only worth interrupting for once it has *stayed*
# that way. A tree mid-edit, a rebase in progress, or a laptop off wifi all clear
# themselves; at a 10-minute tick, notifying immediately would fire ~144 times a
# day for one stuck repo and train the notification to be ignored.
NOTIFY="${NOTIFY:-1}"                        # 0 disables notifications entirely
NOTIFY_AFTER="${NOTIFY_AFTER:-3600}"         # stuck this long (1h) before speaking up
NOTIFY_REPEAT="${NOTIFY_REPEAT:-86400}"      # then at most once a day while still stuck
STATE_DIR="${GIT_SYNC_STATE_DIR:-$HOME/Library/Application Support/git-sync}"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*"; }

state_file() { printf '%s/%s.blocked' "$STATE_DIR" "$(printf '%s' "${1#/}" | tr '/' '_')"; }

notify() { # $1 = repo name, $2 = message
  [ "$NOTIFY" = "1" ] || return 0
  # Strip characters that would break out of the AppleScript string literal.
  local name msg
  name="$(printf '%s' "$1" | tr -d '"\\')"
  msg="$(printf '%s' "$2" | tr -d '"\\')"
  osascript -e "display notification \"$msg\" with title \"git-sync\" subtitle \"$name\"" \
    >/dev/null 2>&1 || true
}

# Record that a repo can't be synced, and notify once it has persisted.
problem() { # $1 = repo, $2 = reason
  local repo="$1" reason="$2" f now first last stuck_h
  log "$repo: $reason"
  now="$(date +%s)"
  mkdir -p "$STATE_DIR" 2>/dev/null || true
  f="$(state_file "$repo")"
  if [ -f "$f" ]; then
    first="$(cut -f1 "$f" 2>/dev/null)"; last="$(cut -f2 "$f" 2>/dev/null)"
  fi
  [ -n "${first:-}" ] || first="$now"
  [ -n "${last:-}" ] || last=0

  if [ $(( now - first )) -ge "$NOTIFY_AFTER" ] && [ $(( now - last )) -ge "$NOTIFY_REPEAT" ]; then
    stuck_h=$(( (now - first) / 3600 ))
    notify "$(basename "$repo")" "$reason — stuck ${stuck_h}h"
    last="$now"
  fi
  printf '%s\t%s\t%s\n' "$first" "$last" "$reason" > "$f"
  return 0
}

# A repo is syncing again. Only says anything if it was previously stuck, so the
# healthy path stays silent.
resolved() { # $1 = repo
  local repo="$1" f last
  f="$(state_file "$repo")"
  [ -f "$f" ] || return 0
  last="$(cut -f2 "$f" 2>/dev/null || echo 0)"
  rm -f "$f"
  log "$repo: syncing again"
  # Only close the loop if it actually interrupted you in the first place.
  [ "${last:-0}" != "0" ] && notify "$(basename "$repo")" "syncing again"
  return 0
}

# Commit local changes, rebase onto origin, push. Mirrors the behaviour of the
# autosync agents this replaced.
sync_push_repo() {
  local repo="$1" gitdir branch committed="" ahead marker

  gitdir="$(git -C "$repo" rev-parse --absolute-git-dir 2>/dev/null)" || return 0

  # Never touch a repo mid-operation. `add -A` during a conflicted rebase or
  # merge commits the conflict markers themselves and buries the operation.
  for marker in rebase-merge rebase-apply MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD BISECT_LOG; do
    if [ -e "$gitdir/$marker" ]; then
      problem "$repo" "$marker present (git operation in progress), left alone"
      return 0
    fi
  done

  # Detached HEAD has no branch to push to. Committing here strands the work in a
  # commit no branch can reach — recoverable only from the reflog, until it is
  # garbage-collected — while `push origin HEAD` fails outright.
  branch="$(git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null)" || branch=""
  if [ -z "$branch" ]; then
    problem "$repo" "detached HEAD, left alone"
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
    resolved "$repo"
  else
    # Only worth reporting if something is actually stranded locally, otherwise a
    # laptop that is merely offline would log on every tick.
    ahead="$(git -C "$repo" rev-list --count "@{upstream}..HEAD" 2>/dev/null || echo 0)"
    if [ -n "$committed" ] || [ "$ahead" != "0" ]; then
      problem "$repo" "push to $branch FAILED, $ahead local commit(s) not on origin"
    else
      # Push failed but nothing is stranded — everything local is already on
      # origin, so there is no problem to report.
      resolved "$repo"
    fi
  fi
  return 0
}

# Which branch origin considers default. Read from origin/HEAD, which git sets at
# clone time — but it is absent on repos built with `git init` + `git remote add`,
# and it goes stale when the remote renames its default branch (the master -> main
# migration), neither of which `git fetch` repairs. Both cases used to fall back to
# "main", find no origin/main, report "0 behind" and drift silently forever.
default_branch() {
  local repo="$1" def cand
  def="$(git -C "$repo" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)"
  def="${def#origin/}"

  # Missing, or naming a branch origin no longer has: ask origin directly.
  if [ -z "$def" ] || ! git -C "$repo" show-ref --verify --quiet "refs/remotes/origin/$def"; then
    git -C "$repo" remote set-head origin --auto >/dev/null 2>&1 || true
    def="$(git -C "$repo" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)"
    def="${def#origin/}"
  fi

  # Remote unreachable or silent about its default: take whichever conventional
  # branch actually exists rather than assuming.
  if [ -z "$def" ] || ! git -C "$repo" show-ref --verify --quiet "refs/remotes/origin/$def"; then
    def=""
    for cand in main master; do
      if git -C "$repo" show-ref --verify --quiet "refs/remotes/origin/$cand"; then def="$cand"; break; fi
    done
  fi
  printf '%s' "$def"
}

# Fast-forward the default branch to origin. Touches nothing else.
refresh_pull_repo() {
  local repo="$1" def head behind stamp age

  git -C "$repo" remote get-url origin >/dev/null 2>&1 || return 0

  # Throttle on OUR last refresh, not on .git/FETCH_HEAD. FETCH_HEAD is shared
  # state that *any* fetch updates — editor autofetch, the Claude Code harness
  # fetching origin before it creates a worktree, a manual `git fetch` — so keying
  # off it meant a frequently-fetched repo looked "just refreshed" on every tick
  # and was never fast-forwarded. Observed in the wild: control.missioncloud.com
  # sat 3 commits behind with a clean tree while a manual ff worked instantly.
  stamp="$(state_file "$repo")"; stamp="${stamp%.blocked}.lastpull"
  if [ -f "$stamp" ]; then
    age=$(( $(date +%s) - $(stat -f %m "$stamp" 2>/dev/null || echo 0) ))
    [ "$age" -lt "$PULL_MIN_AGE" ] && return 0
  fi

  if ! git -C "$repo" fetch --prune --quiet origin 2>/dev/null; then
    problem "$repo" "fetch failed"
    return 0
  fi
  # Only stamp a fetch that worked, so a failing remote is retried next tick.
  mkdir -p "$STATE_DIR" 2>/dev/null || true
  : > "$stamp"

  def="$(default_branch "$repo")"
  if [ -z "$def" ]; then
    problem "$repo" "cannot determine origin's default branch, left alone"
    return 0
  fi

  head="$(git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null)"

  if [ "$head" = "$def" ]; then
    behind="$(git -C "$repo" rev-list --count "HEAD..origin/$def" 2>/dev/null || echo 0)"
    if [ "$behind" = "0" ]; then resolved "$repo"; return 0; fi
    # Only *tracked* changes block the refresh. Untracked files (scratch notes,
    # .env.local, stray build output) accumulate in a working checkout and must not
    # stop it being kept current — git still refuses below if an incoming commit
    # would clobber one of them.
    if [ -n "$(git -C "$repo" status --porcelain --untracked-files=no 2>/dev/null)" ]; then
      problem "$repo" "$def is $behind behind, tracked files modified, left alone"
      return 0
    fi
    if git -C "$repo" merge --ff-only --quiet "origin/$def" 2>/dev/null; then
      log "$repo: $def fast-forwarded $behind commits"
      resolved "$repo"
    elif git -C "$repo" merge-base --is-ancestor HEAD "origin/$def" 2>/dev/null; then
      # HEAD really is an ancestor, so this was a working-tree obstruction rather
      # than divergence — say which, so the log isn't misleading.
      problem "$repo" "$def is $behind behind but a local file is in the way, left alone"
    else
      problem "$repo" "$def could not fast-forward, diverged from origin/$def"
    fi
  else
    # Default branch isn't checked out here, so move its ref without a checkout.
    # No local copy of the default branch at all. Happens after an upstream
    # default-branch rename (master -> main) where the checkout still sits on the
    # old name. Without this, `rev-list $def..origin/$def` errors, gets swallowed
    # into "0 behind", and the repo is silently skipped forever.
    if ! git -C "$repo" show-ref --verify --quiet "refs/heads/$def"; then
      if git -C "$repo" fetch --quiet origin "$def:$def" 2>/dev/null; then
        log "$repo: created local $def from origin (on ${head:-detached HEAD}, not touched)"
        resolved "$repo"
      else
        problem "$repo" "no local $def and could not create it from origin/$def"
      fi
      return 0
    fi

    behind="$(git -C "$repo" rev-list --count "$def..origin/$def" 2>/dev/null || echo 0)"
    if [ "$behind" = "0" ]; then resolved "$repo"; return 0; fi
    if git -C "$repo" fetch --quiet origin "$def:$def" 2>/dev/null; then
      log "$repo: $def advanced $behind commits (on ${head:-detached HEAD}, not touched)"
      resolved "$repo"
    else
      # Ref move refused: local $def has commits origin doesn't, so it can never
      # catch up on its own. Previously this failed silently.
      problem "$repo" "$def is $behind behind and cannot advance, diverged from origin/$def"
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
