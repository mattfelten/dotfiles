# Dotfiles

Wow, such dot. Very file.

## Installation

**First-time setup** (installs NVM + Node if needed, then runs full setup):

```bash
bash scripts/bootstrap.sh
```

Or `./scripts/bootstrap.sh` after cloning. For future updates, run `npm start`.

## Commands

| Command                      | What it do                                                    |
| ---------------------------- | ------------------------------------------------------------- |
| `bash scripts/bootstrap.sh`  | Run once on fresh clone: NVM/Node + npm install + full setup  |
| `npm start`                  | Run full setup in order (homebrew, symlinks, sync, macos)     |
| `npm run homebrew`           | Install Homebrew + Brewfile packages                          |
| `npm run symlinks`           | Symlink dotfiles to ~/                                        |
| `npm run unsymlink`          | Remove our symlinks from ~/                                   |
| `npm run sync`               | Install the git-sync launchd agent                            |
| `npm run sync:uninstall`     | Uninstall the git-sync launchd agent                          |
| `npm run unlink`             | Uninstall the git-sync agent, then remove symlinks            |
| `npm run macos`              | Apply macOS system preferences                                |

### Git sync

`npm run sync` installs one launchd agent (`com.mattfelten.git-sync`) that runs
`scripts/git-sync.sh` over every checkout under `~/Projects` every 10 minutes. It replaces the
old per-repo `*-autosync` agents, and removes them on install. It's part of `npm start`. Tear it
down with `npm run sync:uninstall` (or `npm run unlink` to also remove the symlinks).
Logs: `~/Library/Logs/git-sync.log` — quiet unless something changed or failed.

Two modes, set by `PUSH_RE` at the top of the script:

- **push** (`dotfiles`, `ai-brain`) — repos whose contents we edit directly: commit everything,
  rebase on origin, push. Changes travel between machines automatically.
- **pull** (everything else) — checkouts of shared work: fast-forward the default branch only.
  Never commits, never pushes, never touches a dirty tree, a feature branch, or a worktree.
  Where the default branch isn't checked out its ref is advanced with `git fetch origin main:main`,
  which git refuses unless it's a clean fast-forward.

When a repo **can't** be synced — fetch failed, tracked files modified, diverged from origin,
a local file in the way, a push that failed, a detached HEAD or an abandoned rebase — it's recorded
in `~/Library/Application Support/git-sync/` and shows up in the log. A macOS notification fires only
once the repo has been stuck for `NOTIFY_AFTER` (default 1h), then at most once a day
(`NOTIFY_REPEAT`) while it stays stuck, and once more when it starts syncing again. The delay is the
point: a tree mid-edit, a rebase in progress, or a laptop off wifi all clear on their own, and at a
10-minute tick an immediate notification would fire ~144 times a day for one stuck repo. Set
`NOTIFY=0` to turn them off.

The default branch is whatever `origin/HEAD` says, so `master` repos work the same as `main` ones.
If `origin/HEAD` is missing (repos made with `git init` rather than `git clone`) or stale (the remote
renamed its default branch), it re-asks origin via `git remote set-head --auto`, then falls back to
whichever of `main`/`master` actually exists, and reports rather than skipping if none does.

Pull-only repos are refreshed at most every 25 minutes (`PULL_MIN_AGE`) even though the agent
ticks every 10, so a work checkout doesn't get a pile of commits swapped in under a running dev
server. New clones default to pull mode, which is the safe default.

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
