# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal dotfiles repository. The `install.sh` script symlinks configs into place, generates an SSH key if one is missing, and installs toolchain dependencies (apt, brew, mise). mise manages node, rust (wrapping rustup), uv, and most standalone CLI tools; see `config/mise/config.toml`.

## Repository Structure

- **`dotrc/`** — Files symlinked as `~/.<filename>` (bashrc, zshrc, commonrc-pre, commonrc-post, gitconfig, etc.)
- **`config/`** — Top-level entries symlinked into `~/.config/` under their own names. An entry that is a file lands as a file, so `starship.toml` becomes `~/.config/starship.toml`, not `~/.config/starship/`. Adding a tool's config needs no change to `install.sh`.
- **`cargo/`** — `config.toml`, linked to `$CARGO_HOME/config.toml` by `install.sh`, since cargo doesn't read `~/.config`. It sets the dev profile for every project on the machine, and outranks a project's `Cargo.toml` profiles.
- **`claude/`** — Source files symlinked into `~/.claude/` via `bin/link-claude`: the global `CLAUDE.md`, `settings.json`, `skills/`, `rules/`, and `output-styles/`. Anything else added here lands at the matching path under `~/.claude/`, and a symlink whose source is later deleted is pruned on the next run wherever it sits. Edit these here, not the symlinks in `~/.claude/`.
- **`sources/`** — Shell scripts sourced by `commonrc-pre` at shell startup (aliases, git helpers, path management, etc.)
- **`targets/`** — Package lists for apt and brew (one package per line, kept sorted by pre-commit)
- **`bin/`** — Scripts added to PATH via `dotfiles/bin`; add any executable scripts here and they will be available in the shell (e.g., for Claude Code hooks)

Systemd user units are the exception to `config/`. `install.sh` writes
`cloister-codex.{service,timer}`, `converge-atlas.{service,timer}`,
`sync-branches.{service,timer}`, `tidy.{service,timer}`,
`zellij-session.service`, `zellij-web.service`, `vscode-web.service`, and
`worktrees-web.service` into `~/.config/systemd/user/` rather than symlinking them
from here, because a unit has to name the absolute path of the clone it was
installed from, and only `install.sh` knows where that is. The same directory is
where `claude-scriptorium` and `exe-dev-atlas` write the units
they manage themselves, so symlinking the tree in would point those tools'
writes at this repo.

`sync-branches` runs on every machine, so off exe.dev it is scheduled through a
marked block in the user's crontab instead, cron being the one scheduler a
macOS laptop shares with Linux. On exe.dev `install.sh` removes that block when
it writes the timer, since two schedulers holding the job would run it twice.

All of those units but `sync-branches` and `tidy` are for a person to look at,
so they are gated on `is-dev-box` rather than `is-exe-dev`: a VM running a
workload has nobody reading its session archive and no reason to spend its
proxied ports on an index of itself. It reads the same `dev-box` tag
`exe-dev create-devbox` sets at creation (or `adopt-devbox` on an existing VM),
which is what keeps a bot-box running
`install.sh` on its timer from installing any of them. Reading it back through
reflection rather than off the disk is what lets a box change its mind
(`exe-dev lobby tag <vm> dev-box`) without being rebuilt. `sync-branches` and
`tidy` are gated on `is-exe-dev` instead, since a bot-box has clones to keep
current and a disk to fill just the same; `tidy` is scheduled nowhere else.

They all depend on `Linger=yes` for the account, without which the user manager
starts at first login instead of at boot and every one of them waits for a
connection that the box exists to not need. Nothing here sets it; it comes with
the exeuntu image.

exe.dev proxies one port per VM to the bare `https://<vm>.exe.xyz/` hostname and
forwards 3000-9999 to `https://<vm>.exe.xyz:<port>/`.
[exe-dev-atlas](https://github.com/JoshKarpel/exe-dev-atlas) takes the bare
hostname's port so the front door is an index of everything else. The atlas
sorts by port, so the bottom of the forwarded range is the top of the index, and
the ways in to the box take it: the work session on 3000, VS Code on 3001,
and on 3002 the form that opens a worktree with Claude in it
(`manage-worktrees serve`), which is how new work starts from a phone.
A dev server lands wherever it lands above those, and
services that are only occasionally opened start at 4000, where the codex is.

Neither the atlas nor the codex is implemented here. Both are published tools
this repo installs and converges daily on a timer (`bin/converge-atlas`,
`bin/cloister-codex`), and each writes its own unit naming the interpreter or
binary the install resolved. They come through mise, where an upgrade renders a
changed unit rather than one that looks untouched, and both are exempt from the
mise cooldown in `config/mise/config.toml` so a release is being served the day
after it ships.

## The Work Session

A dev box holds one long-lived zellij session named after its short hostname.
`zellij-session.service` creates it at boot, and joining it is a deliberate act
(`za` from a terminal, or the atlas link to the web client on 3000), never a
side effect of a shell starting. `zellij-restart-session` is how a changed unit
environment, config, or zellij release reaches it, and it ends every pane.
`.claude/rules/work-session.md` covers the units, socket pinning, the web client,
and the failure modes, and loads when one of the files it governs is read.

## Shell Startup Chain

`bashrc`/`zshrc` → `~/.commonrc-pre` (sources every file in `sources/`, adds `bin/`
to PATH) → shell-specific setup → `~/.commonrc-post <shell>` (tool, prompt, and
completion integrations, late PATH overrides, then the stranded-server warning)

The split exists because the two ends of startup have different constraints.
`commonrc-pre` runs early, before mise puts its tools on PATH. `commonrc-post` runs
last and takes the shell's name as an argument, since everything in it is either
shell-parameterised or has to come after the rest of startup.

Within `commonrc-pre`, `sources/` loads before `bin/` joins PATH, so a file there
reaches a bin script only by absolute path through `$DOTFILES` (`sources/exe.sh`
calling `is-exe-dev`). Everything downstream of startup, hooks and prompts included,
can just use the name.

## Key Commands

Each script in `bin/` takes `--help`. What `--help` doesn't say is which ones
run on their own, so running them by hand is only for wanting it now:
`install.sh` schedules `sync-branches` hourly and `tidy` daily (exe.dev only),
and `cloister-codex` and `converge-atlas` daily (dev boxes only).

- `./install.sh` applies the dotfiles and installs dependencies;
  `pre-commit run` runs the hooks.
- `git land` is the one way Claude pushes: it opens or updates the draft PR from
  the draft at `git land --path`. `git yeet` is Josh's quick change on a PR-only
  default branch, auto-merged.
- `tidy` reclaims disk that installed tools can re-download or rebuild;
  `git-disk-usage` (`git du`) splits a checkout's disk use by kind.
- `exe-dev` reaches exe.dev and its VMs (lobby commands, shells, creating or
  adopting a box); `claude-exe-dev` runs Claude Code billed to exe.dev's LLM
  allocation; `vscode-link` prints the URL opening a directory in the VM's
  browser VS Code, which the status line links; `is-dev-box` is the guard the
  person-facing services are gated on.
- `setup-tailscale` joins a machine to the tailnet, per machine and never from
  `install.sh`, since it leaves a daemon running.
- `count-claude-tokens` counts tokens through the Anthropic API
  (needs `ANTHROPIC_API_KEY`).
- `manage-worktrees` (`wt`) runs one git worktree per zellij tab, each with its
  own agent; `manage-worktrees serve` is its web form on 3002.
- The other TUIs: `manage-git` picks branches to delete across clones, with
  the merged ones premarked,
  `manage-ports` shows and stops listeners, `manage-units` drives systemd user
  units, and `pick-just` (`jp`) runs a justfile recipe.
- `zellij-restart-session`, `zellij-web-font`, and `zellij-custom-keybinds`
  manage the work session, the web client's fonts, and the keybindings the
  status bar doesn't advertise.

## Claude Code Hooks

Hooks are registered in `claude/settings.json` and implemented as scripts in
`bin/`. Their design constraints are in `.claude/rules/hooks.md`. The self-test
harness that hooks and other `bin/` scripts carry (`CLAUDE_HOOK_SELFTEST=1
<name>`, run from pre-commit by `claude-hook-selftests`) is in
`.claude/rules/self-tests.md`.

## Claude Code Shell Prefix

`CLAUDE_CODE_SHELL_PREFIX` in `claude/settings.json` names `bin/claude-shell`,
which runs every Bash tool command, hook, and stdio MCP server, each in a
systemd scope inside the memory-capped `claude-work.slice`. A broken
`claude-shell` breaks every Bash call and every hook at once, while Read and
Edit still work, so a session can repair it. `.claude/rules/shell-prefix.md`
covers the rest.

## Claude Code Skills

When asked to write a skill, place it in `claude/skills/` in this dotfiles repo (not in `~/.claude/`); `bin/link-claude` symlinks it into place. Use the `skill-creator` skill for structure and best practices.

## Claude Code Rules

Rules live in `claude/rules/`. A path-less rule loads in every session, and a rule with `paths:` loads on the first Read of a matching file inside the project. Use the `rule-curator` skill to add or update rules; new rules go in `claude/rules/`, not `claude/skills/`. `claude/rules/harness-context.md` sorts guidance into worldview (path-less), a tool's mechanics (scoped to that tool's files), and procedure (a skill), and says why.

Rules are read at runtime, while the work is being done, and a session may load one without the others, so each one stands alone: it glosses any term it borrows and states its ideas outright rather than as analogies to other rules. A cross-reference is appropriate when it tells Claude what to *do* next ("confirm nothing mutates it, see the verify-empirically rule") and the citing sentence still works without it.

A cross-reference describing which rule owns which topic is not. That's maintenance guidance for whoever edits the corpus, it goes stale the moment a rule is split or renamed, and it costs context in every session that loads it. Keep that kind of guidance here instead.

Several rules govern prose, and they split by *axis* rather than by document type
(how to make a case, how a document treats time, how failure gets framed, formatting
by file type), so more than one usually applies at once. Each rule states its own
axis in its opening lines; don't restate them here.

Language rules split the same way, source conventions in one file and project
configuration in another: `rust.md` and `cargo.md`, `python.md` and `pyproject.md`.
In both pairs the config rule's `paths:` are a subset of the source rule's, so the
two are always in context together and neither needs to mention the other.

A path-less rule keeps its principles and leaves each tool's mechanics to that
tool's scoped rule, so the principle loads everywhere and the flag names load
with the files they configure: `supply-chain.md` says why cooldowns matter,
and `pyproject.md`, `mise.md`, and `npm.md` carry each ecosystem's setting.

Guidance about this repo's own files lives in `.claude/rules/`, scoped by
`paths:` to the files it governs, rather than in this file. Every session here
also loads the global `CLAUDE.md` and every path-less global rule, and Claude
Code warns once the always-on total passes 150k characters, so this file keeps
only what a session needs before it has touched anything.

## Claude Code Output Styles

Output styles live in `claude/output-styles/` and go into the system prompt, replacing
Claude Code's built-in software engineering instructions unless the file sets
`keep-coding-instructions: true`. A style that changes only voice or format MUST set it;
without it the harness's own guidance on scoping changes, writing comments, and verifying
work drops out. A style is selected in `/config` or by the `outputStyle` setting, is read
once at session start (so a change needs `/clear`), and reaches the main conversation only,
never a subagent.

Nothing here sets `outputStyle`, deliberately: putting it in the committed `settings.json`
would apply a style to every session on every machine. The `harry` alias in
`sources/aliases.sh` is the per-run alternative, passing the style through
`claude --settings` so it lives and dies with that one process.

## Conventions

- Scripts in `bin/` come in families named by a shared leading word, so typing
  the word and Tab lists the family: `claude-*`, `is-*`, `converge-*`, and the
  TUIs, `pick-*` for choosing one thing and acting on it or printing it, and
  `manage-*` for a live list acted on row by row. Name a new script into its
  family, leading with the family word rather than the object (`manage-git`,
  not `git-manage`). A short name for typing is a shell alias in `sources/`
  (`wt`, `jp`), never the script's own name, and anything that is not an
  interactive shell (a hook, a zellij binding, another script) calls the full
  name, since the alias does not exist there.
- The `pick-*` and `manage-*` TUIs are [counterweight](https://www.counterweight.dev/)
  apps sharing one key scheme and a pure `step` function that their self-tests
  drive. The query is counterweight's `use_text_input` field, so it edits as a shell
  line does; `step` takes the keys that pick or act and returns `None` for the rest,
  which go to the field, so a picking key shadows any edit the field binds to it
  (Ctrl+K moves up rather than killing to the end). Start a new one from the
  closest: `pick-kube` for a one-shot pick, `manage-ports` for a live list. A
  picker run at a shell prompt (`pick-kube`, `pick-just`) draws `Inline` and erases
  itself, so what it hands on lands where it was; one that runs in a pane of its
  own, or a live list, draws full screen.
- Python scripts in `bin/` run under `uv`, not the system interpreter. Use the
  [PEP 723](https://peps.python.org/pep-0723/) inline-script shebang
  `#!/usr/bin/env -S uv run --quiet --script` followed by a `# /// script` metadata
  block declaring `requires-python` (and `dependencies` if any), so the script is
  self-contained and reproducible. A script with dependencies pins each exactly
  (`==`) and sets the cooldown under `[tool.uv]` with my own packages exempted (as
  `config/mise/config.toml` exempts my tools), per the python rule.
  `count-claude-tokens` is
  the exemplar with third-party dependencies; the Python hooks (`claude-rm-scope-check`,
  `claude-gh-api-check`) use the same shebang with an empty dependency set. `--quiet`
  keeps `uv`'s own output off stdout, which matters for hooks whose stdout must stay
  clean (parseable JSON or empty). A `uv run` holds a shared lock on the uv cache
  for its whole life, which is harmless for a short-lived command and blocks every
  `uv cache prune` on the machine for a long-lived one, so a script run as a
  service runs under `uv run --no-cache` rather than its shebang
  (`worktrees-web.service` runs `manage-worktrees serve` that way).
- Shell scripts use 2-space indentation (enforced by beautysh via pre-commit)
- Target files in `targets/` are auto-sorted by the `file-contents-sorter` pre-commit hook
- Pre-commit hooks run via [pre-commit.ci](https://pre-commit.ci) on push; see
  `.pre-commit-config.yaml` for the set. pre-commit.ci skips `claude-hook-selftests`
  (it needs a real dev environment), so the `.github/workflows/pre-commit.yml`
  workflow runs the full suite (that included) on push and PRs. Dependabot keeps the workflow's actions updated.
- The `exists` helper function (from `sources/exists.sh`) is used throughout to check command availability before use
