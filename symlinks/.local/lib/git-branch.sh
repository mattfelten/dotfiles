# Shared helpers for the git-start / sync / propose / delete / rename commands
# in ~/.local/bin. Sourced, not run.
set -euo pipefail

die() { echo "✗ $*" >&2; exit 1; }
current() { git symbolic-ref --quiet --short HEAD || die "Not on a branch"; }
on_origin() { git ls-remote --exit-code --heads origin "$1" >/dev/null 2>&1; }

# origin/HEAD, repaired if missing or stale, else main/master.
default_branch() {
  local def cand
  def="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)"
  def="${def#origin/}"
  if [ -z "$def" ] || ! git show-ref --verify --quiet "refs/remotes/origin/$def"; then
    git remote set-head origin --auto >/dev/null 2>&1 || true
    def="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)"
    def="${def#origin/}"
  fi
  if [ -z "$def" ] || ! git show-ref --verify --quiet "refs/remotes/origin/$def"; then
    def=""
    for cand in main master; do
      if git show-ref --verify --quiet "refs/remotes/origin/$cand"; then def="$cand"; break; fi
    done
  fi
  [ -n "$def" ] || die "Can't tell the default branch for origin"
  printf '%s' "$def"
}

# Fast-forward local main without switching to it. Fails quietly when main is
# checked out or has diverged, which is fine: nothing here depends on it.
update_local_default() {
  git fetch origin "$1:$1" >/dev/null 2>&1 || true
}
