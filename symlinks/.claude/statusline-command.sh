#!/bin/sh
# Claude Code status line - styled after Powerlevel10k Pure theme

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')

# Blue color for directory (matches p10k POWERLEVEL9K_DIR_FOREGROUND=#57C7FF)
blue='\033[38;2;87;199;255m'
# Grey color for git info (matches p10k grey=242)
grey='\033[38;5;242m'
reset='\033[0m'

# Shorten home directory to ~
home="$HOME"
short_cwd="${cwd/#$home/~}"

# Git branch and status
git_info=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  dirty=$(git -C "$cwd" status --porcelain 2>/dev/null | head -1)
  dirty_mark=""
  [ -n "$dirty" ] && dirty_mark="*"
  git_info=" ${grey}${branch}${dirty_mark}${reset}"
fi

printf "${blue}${short_cwd}${reset}${git_info}\n"
