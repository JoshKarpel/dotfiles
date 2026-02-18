# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal dotfiles repository. The `install.sh` script symlinks configs into place and installs toolchain dependencies (apt, brew, uv, nvm, rust/cargo).

## Repository Structure

- **`dotrc/`** — Files symlinked as `~/.<filename>` (bashrc, zshrc, commonrc, gitconfig, etc.)
- **`config/`** — Directories symlinked into `~/.config/` (alacritty, git, bottom, procs, starship)
- **`sources/`** — Shell scripts sourced by `commonrc` at shell startup (aliases, git helpers, path management, etc.)
- **`targets/`** — Package lists for apt, brew, and cargo (one package per line, kept sorted by pre-commit)
- **`bin/`** — Scripts added to PATH via `dotfiles/bin`; add any executable scripts here and they will be available in the shell (e.g., for Claude Code hooks)

## Shell Startup Chain

`bashrc`/`zshrc` → sources `~/.commonrc` → sources every file in `sources/` → adds `bin/` to PATH → loads nvm/cargo/yarn

## Key Commands

```bash
# Apply all dotfiles and install dependencies
./install.sh

# Run pre-commit hooks manually
pre-commit run --all-files
```

## Claude Code Hooks

Active hooks configured in `~/.claude/settings.json`:

- **SessionStart**: `claude-just-list` — Lists available justfile recipes at session start
- **PreToolUse (Bash)**:
  - `claude-uv-check` — Reminds Claude to use `uv run python` in uv projects
  - `claude-head-tail-check` — Reminds Claude to redirect full output to files instead of using head/tail
- **Stop**:
  - `claude-doc-check` — Prompts Claude to update documentation before stopping
  - `claude-sound stop` — Plays stop sound notification
- **Notification**: `claude-sound notify` — Plays notification sound
- **StatusLine**: `claude-statusline` — Custom status line display

## Conventions

- Shell scripts use 2-space indentation (enforced by beautysh via pre-commit)
- Target files in `targets/` are auto-sorted by the `file-contents-sorter` pre-commit hook
- Pre-commit hooks run via [pre-commit.ci](https://pre-commit.ci) on push; hooks include trailing whitespace, end-of-file fixer, YAML/TOML checks, and beautysh formatting
- The `exists` helper function (from `sources/exists.sh`) is used throughout to check command availability before use
