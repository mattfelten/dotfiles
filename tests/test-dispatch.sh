#!/bin/sh
# Tests for the PreToolUse dispatcher.
#
# Builds a throwaway hooks directory with fake checks, so nothing here calls a
# model or touches the real config.

set -u
DISPATCH=$(cd "$(dirname "$0")/.." && pwd)/symlinks/.claude/hooks/dispatch.sh
pass=0
fail=0

check() { # name expected actual
    if [ "$2" = "$3" ]; then
        pass=$((pass + 1))
        printf 'PASS  %s\n' "$1"
    else
        fail=$((fail + 1))
        printf 'FAIL  %s\n      expected [%s]\n      got      [%s]\n' "$1" "$2" "$3"
    fi
}

tab=$(printf '\t')
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/checks"
cp "$DISPATCH" "$work/dispatch.sh"
chmod +x "$work/dispatch.sh"

# A check that always speaks, and records that it ran.
cat > "$work/checks/loud.sh" <<'EOF'
#!/bin/sh
cat > /dev/null
echo "ran" >> "$RANLOG"
printf '{"hookSpecificOutput":{"permissionDecision":"deny","from":"loud"}}'
EOF

# A check that runs but has nothing to say.
cat > "$work/checks/quiet.sh" <<'EOF'
#!/bin/sh
cat > /dev/null
echo "ran" >> "$RANLOG"
EOF

# A check that falls over.
cat > "$work/checks/broken.sh" <<'EOF'
#!/bin/sh
cat > /dev/null
echo "ran" >> "$RANLOG"
exit 3
EOF
chmod +x "$work/checks/loud.sh" "$work/checks/quiet.sh" "$work/checks/broken.sh"

RANLOG="$work/ran.log"
export RANLOG

run() { # conf_contents payload -> stdout, resets the ran log
    : > "$RANLOG"
    printf '%s' "$1" > "$work/checks.conf"
    printf '%s' "$2" | "$work/dispatch.sh"
}
ran_count() { [ -f "$RANLOG" ] && wc -l < "$RANLOG" | tr -d ' ' || echo 0; }

MR='{"tool_input":{"command":"glab mr create --description x"}}'
ORD='{"tool_input":{"command":"npm test && git status"}}'

# 1. a matching glob routes to the check
out=$(run "*glab mr*${tab}checks/loud.sh
" "$MR")
check "matching glob runs the check" '{"hookSpecificOutput":{"permissionDecision":"deny","from":"loud"}}' "$out"

# 2. a non-matching command never starts the check
out=$(run "*glab mr*${tab}checks/loud.sh
" "$ORD")
check "ordinary command: no output" "" "$out"
check "ordinary command: check never ran" "0" "$(ran_count)"

# 3. comments and blank lines are skipped
out=$(run "# a comment

*glab mr*${tab}checks/loud.sh
" "$MR")
check "comments and blanks ignored" '{"hookSpecificOutput":{"permissionDecision":"deny","from":"loud"}}' "$out"

# 4. a check with nothing to say lets the command through
out=$(run "*glab mr*${tab}checks/quiet.sh
" "$MR")
check "silent check allows" "" "$out"
check "silent check did run" "1" "$(ran_count)"

# 5. a check that fails lets the command through
out=$(run "*glab mr*${tab}checks/broken.sh
" "$MR")
check "broken check allows" "" "$out"

# 6. first check to speak wins, later ones are skipped
out=$(run "*glab mr*${tab}checks/loud.sh
*glab mr*${tab}checks/quiet.sh
" "$MR")
check "first responder wins" '{"hookSpecificOutput":{"permissionDecision":"deny","from":"loud"}}' "$out"
check "later check skipped" "1" "$(ran_count)"

# 7. a quiet check does not stop a later one from speaking
out=$(run "*glab mr*${tab}checks/quiet.sh
*glab mr*${tab}checks/loud.sh
" "$MR")
check "quiet then loud still denies" '{"hookSpecificOutput":{"permissionDecision":"deny","from":"loud"}}' "$out"

# 8. a missing script is skipped rather than fatal
out=$(run "*glab mr*${tab}checks/does-not-exist.py
*glab mr*${tab}checks/loud.sh
" "$MR")
check "missing script skipped" '{"hookSpecificOutput":{"permissionDecision":"deny","from":"loud"}}' "$out"

# 9. a non-executable script is skipped
cp "$work/checks/loud.sh" "$work/checks/noexec.sh"
chmod -x "$work/checks/noexec.sh"
out=$(run "*glab mr*${tab}checks/noexec.sh
" "$MR")
check "non-executable skipped" "" "$out"

# 10. last line without a trailing newline is still read
out=$(run "*glab mr*${tab}checks/loud.sh" "$MR")
check "no trailing newline still parsed" '{"hookSpecificOutput":{"permissionDecision":"deny","from":"loud"}}' "$out"

# 11. no registry at all is not fatal
rm -f "$work/checks.conf"
out=$(printf '%s' "$MR" | "$work/dispatch.sh")
check "missing checks.conf allows" "" "$out"

# 12. empty payload is not fatal
printf '%s' "*glab mr*${tab}checks/loud.sh" > "$work/checks.conf"
out=$(printf '' | "$work/dispatch.sh")
check "empty payload allows" "" "$out"

# 13. globs with spaces survive coming out of the file
out=$(run "*gh pr create*${tab}checks/loud.sh
" '{"tool_input":{"command":"gh pr create --body x"}}')
check "glob containing spaces matches" '{"hookSpecificOutput":{"permissionDecision":"deny","from":"loud"}}' "$out"

# 14. the real registry points at scripts that exist and can actually run.
# A check that is present but not executable is skipped in silence, which looks
# exactly like a check that passed.
real_hooks=$(cd "$(dirname "$0")/.." && pwd)/symlinks/.claude/hooks
real_conf="$real_hooks/checks.conf"
if [ -f "$real_conf" ]; then
    problems=""
    while IFS="$tab" read -r glob script rest || [ -n "${glob:-}" ]; do
        case $glob in ''|\#*) continue ;; esac
        [ -n "${script:-}" ] || continue
        [ -f "$real_hooks/$script" ] || problems="$problems missing:$script"
        [ -x "$real_hooks/$script" ] || problems="$problems not-executable:$script"
    done < "$real_conf"
    check "every registered check exists and is executable" "" "$problems"
else
    check "real checks.conf present" "found" "missing"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
