# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

| Command | Description |
|---|---|
| `bash scripts/bootstrap.sh` | First-time setup: installs NVM + Node if needed, then runs full setup |
| `npm start` | Run everything in order: homebrew → symlinks → macos |
| `npm run homebrew` | Install Homebrew + Brewfile packages |
| `npm run symlinks` | Symlink dotfiles from `symlinks/` to `~/` |
| `npm run macos` | Apply macOS system preferences (macOS only) |

## Architecture

This repo uses Node.js (`npm start`) as the orchestration layer over shell scripts and `defaults` commands. The setup pipeline runs three sequential scripts via `npm-run-all`.

**`scripts/homebrew.js`** — Installs Homebrew if missing, then runs `brew bundle` on `homebrew/Brewfile` (cross-platform formulae). On macOS it also runs `homebrew/Brewfile.macos` (casks + Mac App Store apps via `mas`).

**`scripts/symlinks.js`** — Recursively reads `symlinks/` and creates symlinks for each file at the equivalent path under `~/`. If a regular file (non-symlink) exists at the target, it skips with a warning. Existing symlinks are replaced.

**`scripts/macos.js`** — Skips on non-macOS. Requests sudo upfront, then runs each `.sh` file in `macos-defaults/` alphabetically. Safari preferences require Full Disk Access in System Settings to apply successfully.

**`macos-defaults/`** — Shell scripts organized by category (dock, finder, safari, spotlight, system, terminal) that apply `defaults write` commands.

**`symlinks/`** — The actual dotfiles: `.zshrc`, `.aliases`, `.gitconfig`, `.gitignore`, `.editorconfig`, `.p10k.zsh`, `.zsh_plugins.txt`. Adding a file here causes it to be symlinked to `~/` on next `npm run symlinks`.

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
