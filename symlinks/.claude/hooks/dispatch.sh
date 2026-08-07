#!/bin/sh
# PreToolUse dispatcher: one cheap shell gate in front of every check.
#
# Claude Code hook matchers only match a TOOL NAME, so anything watching Bash
# runs on every single Bash call. Starting a Python or Node interpreter that
# then decides it has nothing to do costs ~35ms a time. This gate answers
# "does any check care about this command?" using shell builtins only, and
# starts an interpreter just for the checks that said yes.
#
# The registry is checks.conf next to this file, one check per line:
#
#     <glob><TAB><script>
#
# The glob is matched against the whole hook payload. Keep it LOOSE and cheap,
# for example "*glab mr*" rather than the exact command a check wants. The
# check's own script is what decides for real; the glob only avoids paying for
# an interpreter on commands that obviously don't matter. A glob that is too
# broad just means a check runs and exits quietly. A glob that is too narrow
# silently skips the check, which is the failure worth avoiding.
#
# A check is any executable that reads the payload on stdin and either prints
# a hook JSON response or prints nothing. Its language is its own business,
# the shebang decides. The first check that prints something wins and the rest
# are skipped.
#
# Adding a check: drop the script in checks/, make it executable, add one line
# to checks.conf. This file does not change.
#
# Anything unexpected here lets the command through. A broken gate must never
# be the reason work stops.

set -u

dir=${0%/*}
conf="$dir/checks.conf"
[ -f "$conf" ] || exit 0

payload=$(cat) || exit 0
[ -n "$payload" ] || exit 0

# A literal tab for IFS, written this way so it survives editors that helpfully
# convert tabs to spaces.
tab=$(printf '\t')

while IFS="$tab" read -r glob script rest || [ -n "${glob:-}" ]; do
    case $glob in ''|\#*) continue ;; esac
    [ -n "${script:-}" ] || continue

    # Unquoted on purpose: this is where the glob gets to be a glob.
    # shellcheck disable=SC2254
    case $payload in
        $glob) ;;
        *) continue ;;
    esac

    check="$dir/$script"
    [ -x "$check" ] || continue

    response=$(printf '%s' "$payload" | "$check" 2>/dev/null) || continue
    [ -n "$response" ] || continue

    printf '%s' "$response"
    exit 0
done < "$conf"

exit 0
