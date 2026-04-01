# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal dotfiles repo for macOS/WSL. Manages Homebrew packages, symlinked config files, and macOS system preferences via Node.js scripts.

## Commands

| Command                     | Purpose                                                                |
| --------------------------- | ---------------------------------------------------------------------- |
| `bash scripts/bootstrap.sh` | First-time setup: installs NVM/Node, npm install, then runs full setup |
| `npm start`                 | Run all setup steps in order (homebrew → symlinks → macos)             |
| `npm run homebrew`          | Install Homebrew + bundle Brewfiles                                    |
| `npm run symlinks`          | Symlink files from `symlinks/` to `~/`                                 |
| `npm run macos`             | Apply macOS defaults (requires sudo, skipped on non-macOS)             |

There are no tests or linting configured.

## Architecture

- **`scripts/`** — Node.js scripts (using `chalk` for output) that orchestrate setup. Each `npm run` command maps to a script here. `bootstrap.sh` is the only bash script; it handles NVM/Node bootstrapping before handing off to npm.
- **`symlinks/`** — Files and directories that get symlinked directly into `~/` preserving their relative paths. Includes shell config (`.zshrc`, `.aliases`, `.p10k.zsh`), git config, editorconfig, and a `.claude/` directory with global Claude Code settings.
- **`homebrew/`** — Two Brewfiles: `Brewfile` (cross-platform formulas) and `Brewfile.macos` (casks + Mac App Store apps, macOS only).
- **`macos-defaults/`** — Individual `.sh` scripts for macOS `defaults write` commands, organized by domain (dock, finder, safari, etc.). Run alphabetically. Safari script requires Full Disk Access.
- **`terminal/`** — Terminal.app theme file.

## Key Details

- Uses `npm-run-all` (`run-s`) to sequence the three setup steps.
- The symlinks script won't overwrite existing non-symlink files (it skips them with a warning).
- Uses `git-town` with GitHub connector (`gh`) for branch management.
- Node version pinned via `.nvmrc`.

## Shell Setup

The zsh config uses:

- **Powerlevel10k** for prompt theming (config in `symlinks/.p10k.zsh`)
- **antidote** for zsh plugin management (plugins listed in `symlinks/.zsh_plugins.txt`)
- **NVM** for Node version management (`.nvmrc` pins the Node version)
- **zsh-nvm** plugin for auto-switching Node versions via `NVM_AUTO_USE=true`

## Cross-platform Notes

On non-macOS systems (e.g. WSL), `npm run macos` is a no-op and only `homebrew/Brewfile` (formula only, no casks) is used.

After first-time setup on macOS, enable Homebrew autoupdate manually:

```
brew autoupdate start 43200 --upgrade --cleanup --immediate --sudo
```

## Claude Preferences

- Never include `Co-Authored-By` lines in commit messages
- Never include "Generated with Claude Code" footers in PR descriptions or commit messages
