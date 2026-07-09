# Dotfiles

Wow, such dot. Very file.

## Installation

**First-time setup** (installs NVM + Node if needed, then runs full setup):

```bash
bash scripts/bootstrap.sh
```

Or `./scripts/bootstrap.sh` after cloning. For future updates, run `npm start`.

## Commands

| Command              | What it do                                              |
| -------------------- | ------------------------------------------------------- |
| `bash scripts/bootstrap.sh` | Run once on fresh clone: NVM/Node + npm install + full setup |
| `npm start`          | Run everything below, in order (homebrew, symlinks, macos) |
| `npm run homebrew`   | Install Homebrew + Brewfile packages                    |
| `npm run symlinks`   | Symlink dotfiles to ~/ + install the git autosync agent |
| `npm run unsymlink`  | Remove our symlinks from ~/ + uninstall the autosync agent |
| `npm run macos`      | Apply macOS system preferences                          |

### Git autosync

`npm run symlinks` also installs a launchd agent (`com.mattfelten.dotfiles-autosync`)
that commits, pulls, and pushes this repo every 10 minutes, so changes travel between
machines automatically. `npm run unsymlink` removes it. Logs: `~/Library/Logs/dotfiles-autosync.log`.

### Synced Claude Code config

`symlinks/.claude/` carries the portable parts of `~/.claude`: `CLAUDE.md`, `settings.json`,
`keybindings.json`, `statusline-command.sh`, and hand-authored `skills/`. Under `skills/`,
each entry is symlinked individually so our synced skills coexist with machine-specific ones
(marketplace-managed skills) that stay local and reinstall per machine.

Plugins are **not** file-synced: their manifests embed absolute, per-user install paths
(`/Users/<you>/...`) that differ across machines. Instead, plugin enablement travels in
`settings.json` (`enabledPlugins` + `extraKnownMarketplaces`), and each machine reinstalls
its own plugin cache from that.

## Structure

```
symlinks/       → Files that get symlinked to ~/
homebrew/       → Brewfile (cross-platform formula), Brewfile.macos (casks + mas, macOS only)
macos-defaults/ → Shell scripts for macOS settings
scripts/        → The JS that makes it all go
```

On non-macOS (e.g. WSL), only the main Brewfile is used and `npm run macos` is skipped.
