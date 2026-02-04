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
| `npm run symlinks`   | Symlink dotfiles to ~/                                  |
| `npm run macos`      | Apply macOS system preferences                          |

## Structure

```
symlinks/       → Files that get symlinked to ~/
homebrew/       → Brewfile (cross-platform formula), Brewfile.macos (casks + mas, macOS only)
macos-defaults/ → Shell scripts for macOS settings
scripts/        → The JS that makes it all go
```

On non-macOS (e.g. WSL), only the main Brewfile is used and `npm run macos` is skipped.
