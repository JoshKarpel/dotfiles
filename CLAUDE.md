# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal dotfiles repository. The `install.sh` script symlinks configs into place and installs toolchain dependencies (apt, brew, uv, nvm, rust/cargo).

## Repository Structure

- **`dotrc/`** — Files symlinked as `~/.<filename>` (bashrc, zshrc, commonrc, gitconfig, etc.)
- **`config/`** — Directories symlinked into `~/.config/` (alacritty, git, bottom, procs, starship)
- **`claude/`** — Source files symlinked into `~/.claude/` via `bin/link-claude`: the global `CLAUDE.md`, `settings.json`, and `skills/`. Edit these here, not the symlinks in `~/.claude/`.
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
pre-commit run
```

## Claude Code Hooks

Active hooks configured in `~/.claude/settings.json`:

- **SessionStart**:
  - `claude-just-list` — Lists available justfile recipes at session start
  - `claude-git-status` — Shows git status at session start
  - `claude-gh-status` — If authenticated and in a GitHub-backed repo, injects the current repo name/URL and a reminder that `gh` commands default to it
- **PreToolUse (Bash)**:
  - `claude-uv-check` — Reminds Claude to use `uv run python` in uv projects
  - `claude-read-check` — Blocks `sed -n X,Yp`, `head -n N file`, and `tail -n N file` used just to read files; tells Claude to use the Read tool with `offset`/`limit` instead
  - `claude-shell-comment-check` — Blocks any shell command containing `#`; tells Claude to write to a temp script file instead
  - `claude-git-dash-c-check` — Blocks `git -C <dir>` when the path resolves to the current repository (redundant; just run without `-C`); allows it when targeting a different repo
- **Stop**:
  - `claude-precommit-stop` — Checks for untracked files first (exits 2 if any); then runs `git add --update` and if pre-commit is configured runs it twice (auto-fixes + re-stage between runs); exits 2 if still failing
  - `claude-sound stop` — Plays stop sound notification
- **Notification**: `claude-sound notify` — Plays notification sound
- **StatusLine**: `claude-statusline` — Custom status line display

## Hook Design

Hooks run in non-interactive shell subprocesses, so functions defined in `sources/` (e.g., `exists`) are **not available**. Any shared logic needed by hooks must be a standalone script in `bin/`, not a sourced function.

## Claude Code Skills

When asked to write a skill, place it in `claude/skills/` in this dotfiles repo (not in `~/.claude/`); `bin/link-claude` symlinks it into place. Use the `skill-creator` skill for structure and best practices, and `style-curator` when the skill belongs to the `style-*` family of language/tool style guides.

## Conventions

- Shell scripts use 2-space indentation (enforced by beautysh via pre-commit)
- Target files in `targets/` are auto-sorted by the `file-contents-sorter` pre-commit hook
- Pre-commit hooks run via [pre-commit.ci](https://pre-commit.ci) on push; hooks include trailing whitespace, end-of-file fixer, YAML/TOML checks, and beautysh formatting
- The `exists` helper function (from `sources/exists.sh`) is used throughout to check command availability before use
