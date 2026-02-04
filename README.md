# Dotfiles

Wow, such dot. Very file.

## Installation

```bash
npm install && npm start
```

Easy peasy, lemon squeezy.

## Commands

| Command            | What it do                           |
| ------------------ | ------------------------------------ |
| `npm start`        | Run everything below, in order       |
| `npm run homebrew` | Install Homebrew + Brewfile packages |
| `npm run node`     | Install nvm + Node                   |
| `npm run symlinks` | Symlink dotfiles to ~/               |
| `npm run macos`    | Apply macOS system preferences       |

## Structure

```
symlinks/       → Files that get symlinked to ~/
homebrew/       → Brewfile lives here
macos-defaults/ → Shell scripts for macOS settings
scripts/        → The JS that makes it all go
```
