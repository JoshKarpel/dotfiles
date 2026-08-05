# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal dotfiles repository. The `install.sh` script symlinks configs into place, generates an SSH key if one is missing, and installs toolchain dependencies (apt, brew, mise). mise manages node, rust (wrapping rustup), uv, cargo plugins (via the `cargo:` backend), and most standalone CLI tools; see `config/mise/config.toml`.

## Repository Structure

- **`dotrc/`** — Files symlinked as `~/.<filename>` (bashrc, zshrc, commonrc-pre, commonrc-post, gitconfig, etc.)
- **`config/`** — Entries symlinked into `~/.config/`: directories (`git/`, `bottom/`, `mise/`, `zellij/`) and the single file `starship.toml` (symlinked as `~/.config/starship.toml`, not `~/.config/starship/`)
- **`claude/`** — Source files symlinked into `~/.claude/` via `bin/link-claude`: the global `CLAUDE.md`, `settings.json`, `skills/`, `rules/`, and `commands/` (personal slash commands, invoked only when explicitly run, e.g. `/disco`). Edit these here, not the symlinks in `~/.claude/`.
- **`sources/`** — Shell scripts sourced by `commonrc-pre` at shell startup (aliases, git helpers, path management, etc.)
- **`targets/`** — Package lists for apt and brew (one package per line, kept sorted by pre-commit)
- **`bin/`** — Scripts added to PATH via `dotfiles/bin`; add any executable scripts here and they will be available in the shell (e.g., for Claude Code hooks)

## Shell Startup Chain

`bashrc`/`zshrc` → `~/.commonrc-pre` (sources every file in `sources/`, adds `bin/`
to PATH) → shell-specific setup → `~/.commonrc-post <shell>` (activates mise,
starship, gh, cargo, then `start_zellij_welcome`)

The split exists because the two ends of startup have different constraints.
`commonrc-pre` runs early, before mise puts its tools on PATH. `commonrc-post` runs
last and takes the shell's name as an argument, since everything in it is either
shell-parameterised or has to come after the rest of startup — `start_zellij_welcome`
`exec`s zellij on exe.dev VMs, so nothing after it would run.

## Key Commands

```bash
# Apply all dotfiles and install dependencies
./install.sh

# Run pre-commit hooks manually
pre-commit run

# Count Claude tokens in files/dirs via the Anthropic count_tokens API
# (needs ANTHROPIC_API_KEY). Run with --help for usage and flags.
count-claude-tokens --help

# Create an exe.dev dev box from this repo, or cut a new one over to an
# existing name. Run with --help for subcommands and flags.
exe-dev --help
```

## Claude Code Hooks

Hooks are registered in `claude/settings.json` and implemented as scripts in `bin/`.
Read those two for which hooks exist, what events they fire on, and what each one
does. What follows is only what neither source states.

### Design Constraints

- Hooks run in non-interactive shell subprocesses, so functions defined in
  `sources/` (e.g. `exists`) are _not_ available. Shared logic needed by hooks must
  be a standalone script in `bin/`, not a sourced function.
- Hooks registered together in one group run in parallel, with no guaranteed order.
  `claude-stop` is therefore an orchestrator rather than a group: it runs its checks
  in sequence and plays the stop sound only when none of them blocked, so the sound
  means Claude is actually stopping rather than retrying after a block.
- Stop hooks return JSON: `additionalContext` carries a message to Claude without
  displaying it in the TUI, `systemMessage` shows a brief visible indicator.
- A hook that auto-approves has to prove the _whole_ command is safe, while one that
  blocks needs only a single bad segment. `claude-gh-api-check` and
  `claude-awk-check` are both built around that asymmetry: `allow` requires every
  segment to be read-only, and anything unproven emits nothing so the call falls
  through to the normal prompt.
- `claude-changeset-guard` is the shared helper for firing at most once per
  change-set. It fingerprints the working diff plus untracked files, keys the result
  per branch, and stores state under the git directory.
- The `deny` list in `settings.json` stays thin on purpose. `claude-rm-scope-check`
  decides whether an `rm` escapes the work area, so `deny` keeps only the
  never-in-scope catastrophic backstops it can't reason about.

### Hook Self-Tests

A hook with non-trivial matching carries its own tests, gated on the
`CLAUDE_HOOK_SELFTEST` environment variable so nothing pollutes its real arguments.
Run a hook's tests with `CLAUDE_HOOK_SELFTEST=1 <hook-name>`; it prints results and
exits 0 (pass) or 1 (fail). Keep the harness embedded in the hook rather than
factored into a shared script: a hook should stay self-contained and
copy-pasteable, and a small duplicated harness is a better trade than a hidden
dependency.

Each participating hook carries a `# CLAUDE_HOOK_SELFTEST` marker comment line as an
explicit declaration. The `claude-hook-selftests` runner discovers the set from those
markers, so there's no separate list to drift. It's wired into pre-commit
(`files: ^bin/`), so a hook regression fails the commit. A missing dependency (`jq`,
`python3`) surfaces as a failed run rather than a silent pass, since the hook whose
tests can't run exits non-zero.

- **Bash hooks** embed a ~10-line block right after `set -euo pipefail` (before
  reading stdin). It defines a `t <want-exit> <command>` helper that re-invokes the
  hook (`CLAUDE_HOOK_SELFTEST= "$0"`) with a crafted `{tool_input:{command:…}}`
  payload and asserts the exit code. See `claude-http-server-bind-check` for the
  copy-paste template.
- **Python hooks** check the env var in `main()` and run an embedded case matrix
  against a pure `(command, cwd, repo_root) -> …` function, so the tests need no git
  or filesystem. See `claude-rm-scope-check`.
- A hook whose result depends on external state is **not** self-tested this way
  (`claude-uv-check` needs a uv project, `claude-git-dash-c-check` needs a specific
  git repo). A black-box self-test can't set that up deterministically without a
  fixture.

## Claude Code Skills

When asked to write a skill, place it in `claude/skills/` in this dotfiles repo (not in `~/.claude/`); `bin/link-claude` symlinks it into place. Use the `skill-creator` skill for structure and best practices.

## Claude Code Rules

Rules live in `claude/rules/` and load automatically when Claude works with matching file types (if `paths:` frontmatter is set) or globally (if not). Use the `rule-curator` skill to add or update rules; new rules go in `claude/rules/`, not `claude/skills/`.

Rules are read at runtime, while the work is being done, so each one describes what it does concretely and on its own terms. A cross-reference is appropriate when it tells Claude what to *do* next ("confirm nothing mutates it, see the verify-empirically rule").

A cross-reference describing which rule owns which topic is not. That's maintenance guidance for whoever edits the corpus, it goes stale the moment a rule is split or renamed, and it costs context in every session that loads it. Keep that kind of guidance here instead.

Several rules govern prose, and they split by *axis* rather than by document type
(how to make a case, how a document treats time, how failure gets framed, formatting
by file type), so more than one usually applies at once. Each rule states its own
axis in its opening lines; don't restate them here.

Language rules split the same way, source conventions in one file and project
configuration in another: `rust.md` and `cargo.md`, `python.md` and `pyproject.md`.
In both pairs the config rule's `paths:` are a subset of the source rule's, so the
two are always in context together and neither needs to mention the other.

## Conventions

- Python scripts in `bin/` run under `uv`, not the system interpreter. Use the
  [PEP 723](https://peps.python.org/pep-0723/) inline-script shebang
  `#!/usr/bin/env -S uv run --quiet --script` followed by a `# /// script` metadata
  block declaring `requires-python` (and `dependencies` if any), so the script is
  self-contained and reproducible. `count-claude-tokens` is the exemplar with
  third-party dependencies; the Python hooks (`claude-rm-scope-check`,
  `claude-gh-api-check`) use the same shebang with an empty dependency set. `--quiet`
  keeps `uv`'s own output off stdout, which matters for hooks whose stdout must stay
  clean (parseable JSON or empty).
- Shell scripts use 2-space indentation (enforced by beautysh via pre-commit)
- Target files in `targets/` are auto-sorted by the `file-contents-sorter` pre-commit hook
- Pre-commit hooks run via [pre-commit.ci](https://pre-commit.ci) on push; see
  `.pre-commit-config.yaml` for the set. pre-commit.ci skips `claude-hook-selftests`
  (it needs a real dev environment), so the `.github/workflows/pre-commit.yml`
  workflow runs the full suite (self-tests included) on push and PRs. Dependabot
  keeps the workflow's actions updated.
- The `exists` helper function (from `sources/exists.sh`) is used throughout to check command availability before use
