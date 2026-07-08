#!/usr/bin/env bash
# Claude Code status line: git branch, model, context + rate limit usage

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
model=$(echo "$input" | jq -r '.model.display_name // ""')
ctx=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
five_h=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
week=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# ANSI colors
RESET=$'\033[0m'
DIM=$'\033[2m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RED=$'\033[31m'

# gauge LABEL PCT -> "label ▰▰▰▱▱ 42%" with color by threshold
gauge() {
  local label=$1 pct=$2
  [ -z "$pct" ] && return
  local n
  n=$(printf '%.0f' "$pct")
  # 5-segment bar
  local filled=$(( (n + 10) / 20 ))
  [ $filled -gt 5 ] && filled=5
  [ $filled -lt 0 ] && filled=0
  local empty=$(( 5 - filled ))
  local bar=""
  local i
  for ((i=0; i<filled; i++)); do bar="${bar}█"; done
  for ((i=0; i<empty; i++)); do bar="${bar}░"; done
  # color by threshold
  local color=$GREEN
  [ $n -ge 60 ] && color=$YELLOW
  [ $n -ge 85 ] && color=$RED
  printf '%s%s %s%s %d%%%s' "$DIM" "$label" "$color" "$bar" "$n" "$RESET"
}

# Git branch and dirty status
git_info=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null | sed 's/^/@/')
  dirty=$(git -C "$cwd" status --porcelain 2>/dev/null)
  git_info="$branch"
  [ -n "$dirty" ] && git_info="$git_info*"
fi

# Assemble: branch*  model  ctx ▰▰▰▱▱ 42%  5h …  7d …
sep="  "
parts=""
[ -n "$git_info" ] && parts="$git_info"
[ -n "$model" ] && parts="${parts:+$parts$sep}${DIM}${model}${RESET}"

ctx_g=$(gauge "ctx" "$ctx")
five_g=$(gauge "5h" "$five_h")
week_g=$(gauge "7d" "$week")

[ -n "$ctx_g" ] && parts="${parts:+$parts$sep}$ctx_g"
[ -n "$five_g" ] && parts="${parts:+$parts$sep}$five_g"
[ -n "$week_g" ] && parts="${parts:+$parts$sep}$week_g"

printf "%s" "$parts"
