# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal dotfiles repository. The `install.sh` script symlinks configs into place and installs toolchain dependencies (apt, brew, mise). mise manages node, rust (wrapping rustup), uv, cargo plugins (via the `cargo:` backend), and most standalone CLI tools; see `config/mise/config.toml`.

## Repository Structure

- **`dotrc/`** — Files symlinked as `~/.<filename>` (bashrc, zshrc, commonrc, gitconfig, etc.)
- **`config/`** — Entries symlinked into `~/.config/`: directories (`git/`, `bottom/`, `mise/`) and the single file `starship.toml` (symlinked as `~/.config/starship.toml`, not `~/.config/starship/`)
- **`claude/`** — Source files symlinked into `~/.claude/` via `bin/link-claude`: the global `CLAUDE.md`, `settings.json`, `skills/`, and `rules/`. Edit these here, not the symlinks in `~/.claude/`.
- **`sources/`** — Shell scripts sourced by `commonrc` at shell startup (aliases, git helpers, path management, etc.)
- **`targets/`** — Package lists for apt and brew (one package per line, kept sorted by pre-commit)
- **`bin/`** — Scripts added to PATH via `dotfiles/bin`; add any executable scripts here and they will be available in the shell (e.g., for Claude Code hooks)

## Shell Startup Chain

`bashrc`/`zshrc` → sources `~/.commonrc` → sources every file in `sources/` → adds `bin/` to PATH → activates mise (node + CLI tools), starship, gh, and cargo

## Key Commands

```bash
# Apply all dotfiles and install dependencies
./install.sh

# Run pre-commit hooks manually
pre-commit run

# Count Claude tokens in files/dirs via the Anthropic count_tokens API
# (needs ANTHROPIC_API_KEY). Run with --help for usage and flags.
count-claude-tokens --help
```

## Claude Code Hooks

Active hooks configured in `~/.claude/settings.json`:

- **SessionStart**:
  - `claude-just-list` — Lists available justfile recipes at session start
  - `claude-pre-commit-reminder` — If the repo uses pre-commit, points Claude at the `pre-commit-autofix` helper
  - `claude-git-status` — Shows git status at session start
  - `claude-gh-status` — If authenticated and in a GitHub-backed repo, injects the current repo name/URL and a reminder that `gh` commands default to it; also surfaces the current branch's open PR (number, title, stub `gh pr` commands, and a pointer to the `handle-pr-review` skill) when one exists, and the latest GitHub Actions CI run on the branch only when it failed (workflow, conclusion, stub `gh run` commands, and a pointer to the `debug-gha` skill)
- **PreToolUse (Bash)**:
  - `claude-uv-check` — Reminds Claude to use `uv run python` in uv projects
  - `claude-read-check` — Blocks `sed -n X,Yp`, `head -n N file`, and `tail -n N file` used just to read files; tells Claude to use the Read tool with `offset`/`limit` instead
  - `claude-shell-comment-check` — Blocks shell commands where `#` appears as a comment (preceded by whitespace or at the start of the command); the permission harness truncates at `#`, causing pattern matching to fail; tells Claude to write a temp script file instead
  - `claude-git-dash-c-check` — Blocks `git -C <dir>` when the path resolves to the current repository (redundant; just run without `-C`); allows it when targeting a different repo
- **Stop**: `claude-stop` runs the checks below in sequence (not parallel, since hooks in
  a group otherwise run in parallel and order isn't guaranteed) and only plays the stop
  sound if none of them blocked, so the sound means Claude is actually stopping rather
  than retrying after a block. First, if Claude's last message looks like a question
  (contains `?`), it's handing control back to the user, so the orchestrator skips every
  check, plays the stop sound, and lets Claude stop:
  - `claude-stop-precommit` — Checks for untracked files first; then runs
    `git add --update` and if pre-commit is configured runs it, exiting early on
    success; on failure, re-stages auto-fixes (`git add --update`) and runs it once more,
    blocking if still failing
  - `claude-stop-finish` — Once per change-set, nudges Claude through a structured
    finishing pass: (1) consistency updates (CLAUDE.md, docs, changelogs, etc.),
    (2) verify the changes work (e.g. build, type-checking, tests).
    Uses the shared `claude-changeset-guard` helper: fires once per never-before-seen
    change-set (fingerprinted via `git diff HEAD` + untracked files, keyed per branch,
    stored in `.git/claude-finish/`), re-fires only when Claude changes the diff, and
    goes quiet once a pass produces no changes. Skips during merge/rebase.

  All Stop hooks output JSON: `additionalContext` carries the message to Claude
  without displaying it in the TUI; `systemMessage` shows a brief visible indicator.
  - `claude-sound stop` — Plays stop sound notification
- **Notification**: `claude-sound notify` — Plays notification sound
- **StatusLine**: `claude-statusline` — Custom status line display

## Hook Design

Hooks run in non-interactive shell subprocesses, so functions defined in `sources/` (e.g., `exists`) are **not available**. Any shared logic needed by hooks must be a standalone script in `bin/`, not a sourced function.

## Claude Code Skills

When asked to write a skill, place it in `claude/skills/` in this dotfiles repo (not in `~/.claude/`); `bin/link-claude` symlinks it into place. Use the `skill-creator` skill for structure and best practices.

## Claude Code Rules

Rules live in `claude/rules/` and load automatically when Claude works with matching file types (if `paths:` frontmatter is set) or globally (if not). Use the `rule-curator` skill to add or update rules; new rules go in `claude/rules/`, not `claude/skills/`.

## Conventions

- Shell scripts use 2-space indentation (enforced by beautysh via pre-commit)
- Target files in `targets/` are auto-sorted by the `file-contents-sorter` pre-commit hook
- Pre-commit hooks run via [pre-commit.ci](https://pre-commit.ci) on push; hooks include trailing whitespace, end-of-file fixer, YAML/TOML checks, and beautysh formatting
- The `exists` helper function (from `sources/exists.sh`) is used throughout to check command availability before use
