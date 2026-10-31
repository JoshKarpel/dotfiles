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
`zellij-session.service`, `zellij-web.service`, and `vscode-web.service` into `~/.config/systemd/user/` rather than symlinking them
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
`exe-dev create-devbox` sets at creation, which is what keeps a bot-box running
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
the ways in to the box take it: the work session on 3000 and VS Code on 3001.
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
`zellij-session.service` creates it at boot, which is what makes it outlive the
last logout rather than only the last dropped connection. Creating it on login
instead would tie its existence to somebody having connected, so a
reboot would quietly discard it until the next login.

Joining it is a deliberate act, never a side effect of a shell starting: `za`
(`sources/zellij.sh`) from a terminal, or the atlas link to the web client. A
login lands at a plain prompt, so a tool that opens a shell for its own purposes
(VS Code resolving its environment, an editor terminal) gets a shell rather than
a client attached to the session someone is looking at elsewhere.

`zellij-web.service` then serves that session at
`https://<vm>.exe.xyz:3000/<session>`, which needs `web_sharing "on"` in
`config/zellij/config.kdl`: the web server serves sessions it created itself
whatever that setting says, and the work session is created outside it.

The atlas links each session by name rather than linking the web server's root,
because arriving there without a session in the path creates a new one. It
offers a VS Code Remote-SSH link to the box alongside them, and withholds both
from a caller who is not the VM's owner. How it decides that belongs to
[exe-dev-atlas](https://github.com/JoshKarpel/exe-dev-atlas) rather than to
anything here.

`vscode-web.service` is the other half of that link: `code serve-web` on 3001,
kept alongside it rather than replacing it. The two differ in where the
workbench runs, which decides where its settings come from. Remote-SSH runs it
on the laptop and inherits the settings already there. `serve-web` runs it here
and keeps user settings in the browser's IndexedDB rather than on disk, so a
`settings.json` on the box is not read and Settings Sync has to be signed in per
browser. The CLI comes from mise rather than the copy Remote-SSH pushes to
`~/.vscode-server/code-<commit>`, whose path moves with every VS Code update.

A few details are worth knowing before touching any of this.

Both units start zellij through a login shell (`bash -lc`) rather than with an
environment of their own. Every pane inherits the server's environment rather
than the attaching client's, and a pane zellij resurrects runs its serialized
command directly, with no shell of its own, so the server's environment is the
only one it ever gets. Pinning variables in the unit one at a time is a second
copy of shell startup, and every variable it misses breaks only in resurrected
panes. `TERM` is the one exception, set by `env` in `config/zellij/config.kdl`,
since zellij is the terminal its panes run in. Only a CLI client applies that
block to the server it spawns, so `zellij-web.service` pins the same value for
the sessions `zellij web` creates, and starts after the work session so that a
browser tab reconnecting at boot cannot create the work session first.

Zellij keys its session sockets off `$XDG_RUNTIME_DIR` and falls back to
`/tmp/zellij-$UID` when it is unset. A systemd user unit always has it and sshd
here never does, so the unit and the logins it exists to serve would build two
separate sessions of the same name. `sources/exe.sh` pins `ZELLIJ_SOCKET_DIR`,
and the login shell carries that pin into the units.

A server the shell cannot see through that socket directory may as well not
exist: `attach --create` builds a second session of the same name beside it and
nothing about the result looks wrong. Zellij covers the ordinary case itself,
declining to clobber a live server whose socket is on disk even when that server
is too busy to answer, so what is left is the server whose socket was unlinked
under it and the server started against a different directory. Neither is
recoverable, since an unlinked socket cannot be relinked and the panes live in
the server's memory, so `warn_stranded_zellij_servers` reports them rather than
letting the loss pass silently. It runs at the end of login rather than inside
`za`, where the message would be wiped by zellij taking the terminal, and it is
what makes the warning readable at all: a prompt holds it on screen.

`zellij attach --create-background` is the only way to make a session with no
controlling terminal, and it exits 1 with "Session already exists" rather than
succeeding as a no-op, hence `SuccessExitStatus=1`. A real failure panics and
exits 101, so tolerating 1 does not hide one.

Whether the session survives the unit depends on who started its server. The
server `attach --create-background` starts stays in the unit's cgroup, and
`KillMode=control-group` means `stop` and `restart` SIGTERM it, ending every
pane and leaving its socket file behind. A server `za` created from a login
because the unit's was missing lives in that login's scope instead, and the unit
cannot touch it. `zellij-restart-session` covers both: it ends the session with
`zellij kill-session`, which reaches either kind cleanly, then restarts the unit,
and it is how a changed unit environment or config reaches the server. The one
time `install.sh` runs it is when mise has upgraded zellij underneath the
session, losing every pane, unless `install.sh` is itself running inside that
session, where it skips and says to run it by hand after detaching.

The token that gets you into the web client is minted per box with
`zellij web --create-token`, displayed once, and hashed into
`~/.local/share/zellij/tokens.db`. Nothing in this repo can provision it, so it
is a manual step per box.

`bin/exe-dev` writes units there too, from the setup script `create-botbox`
sends: a bot-box has nobody to run the installer on it, so it gets a timer that
does. Those name no clone (`%h` reaches the home directory, and systemd resolves
a specifier wherever it appears, quoting included), and are written at first boot
rather than on every converge, so a change to them reaches only boxes built
afterwards.

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

```bash
# Apply all dotfiles and install dependencies
./install.sh

# Run pre-commit hooks manually
pre-commit run

# Reclaim disk by removing what installed tools can re-download or rebuild.
# install.sh schedules it daily on exe.dev VMs, and `update` runs it after
# install.sh; run it by hand to reclaim now.
tidy

# Count Claude tokens in files/dirs via the Anthropic count_tokens API
# (needs ANTHROPIC_API_KEY). Run with --help for usage and flags.
count-claude-tokens --help

# Reach exe.dev and its VMs over checked host keys: run lobby commands, open a
# shell or a VS Code window on a box, create one from this repo, cut a new one
# over to an existing name, or print the URL the box you are on answers at.
# Run with --help for subcommands and flags.
exe-dev --help

# Run Claude Code billed against exe.dev's LLM allocation rather than the
# claude.ai subscription. exe.dev VMs only. Takes claude's own flags.
claude-exe-dev --model opus

# Fast-forward every local branch to its upstream, in every clone under
# ~/projects and ~/work, skipping any checked out in a worktree with changes to
# tracked files and reporting any that have diverged. install.sh schedules it
# hourly, so running it by hand is only for wanting it now.
sync-branches

# Install Tailscale and join this machine to the tailnet. Run per-machine, not
# from install.sh: it leaves a daemon running and joins a private network.
setup-tailscale

# Update claude-scriptorium and converge the systemd user service that serves
# this machine's sessions. Dev-box VMs only; a no-op anywhere else. install.sh
# schedules it daily, so running it by hand is only for wanting a release now.
cloister-codex

# Update exe-dev-atlas and converge the systemd user service that serves this
# VM's front door: proxied ports, zellij sessions, and VS Code workspaces, with a
# link to each. Dev-box VMs only; a no-op anywhere else. install.sh schedules it
# daily, so running it by hand is only for wanting a release now.
converge-atlas

# End this box's zellij work session and start it again on a fresh server, so a
# changed unit environment, config, or zellij release reaches it. Every pane
# ends, so it refuses to run from inside zellij.
zellij-restart-session

# Print or set the font list zellij's web client draws with, one family name per
# argument. A connected browser tab follows the edit live; the fonts have to be
# installed where the browser runs.
zellij-web-font "FiraCode Nerd Font" "Fira Code"

# List the keybindings config/zellij/config.kdl adds or unbinds, which the
# status bar never advertises: key, modes, and actions, read from the file.
zellij-custom-keybinds

# One git worktree per zellij tab, each running its own agent, aliased `wt`:
# `wt new` opens a branch in <repo>.worktrees/<branch> beside the clone, in a
# tab of its own, and `wt done` removes the worktree and closes its tab. `wt`
# alone (Alt+Shift+e in zellij) picks the clone, from ~/projects and ~/work, and
# the worktree or new branch instead of taking them as arguments. The
# claude-tab-status hook marks each tab working (●), waiting on you (?), paused
# on background work or a scheduled job that will wake it (◌), or finished (✓).
# Run with --help for subcommands and flags.
manage-worktrees --help

# Pick local branches across every clone to delete (Alt+Shift+d in zellij),
# with the ones merged or squash-merged into origin/HEAD already marked. A
# branch checked out in a worktree goes through `wt done`, tab and all.
manage-git

# See what is listening on which TCP port, copy a port's URL (exe.dev's on a VM),
# and stop the process behind one: the interactive port-user and port-kill.
manage-ports

# See this account's own systemd user services, folded together with their
# timers, and the highlighted one's journal, and start, restart, or stop them.
manage-units

# Pick a recipe from the justfile here and run it, typing any arguments after
# its name. Aliased `jp`; Alt+j in zellij runs it in the focused pane's
# directory and holds the output until a key.
pick-just

# Exit 0 only on an exe.dev VM tagged `dev-box`. The guard the services that
# exist to be looked at by a person are gated on.
is-dev-box
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
  in sequence and announces the stop only when none of them blocked, so an
  announcement means Claude is actually stopping rather than retrying after a block.
- Stop hooks return JSON: `additionalContext` carries a message to Claude without
  displaying it in the TUI, `systemMessage` shows a brief visible indicator.
- A hook that auto-approves has to prove the _whole_ command is safe, while one that
  blocks needs only a single bad segment. `claude-gh-api-check` and
  `claude-awk-check` are both built around that asymmetry: `allow` requires every
  segment to be read-only, and anything unproven emits nothing so the call falls
  through to the normal prompt.
- `claude-changeset-guard` is the shared helper for firing at most once per
  change-set. It fingerprints the working diff plus untracked files, keys the result
  per branch, and stores state under the git directory. Once per change-set is not
  enough for a nudge that asks for edits, since those edits are themselves a new
  change-set, so `claude-stop-finish` also fires at most once per `prompt_id`.
- A hook whose only job is a side effect still has to keep all three channels clean:
  the event decides how stdout is read (on `PreToolUse` a JSON object there is a
  permission decision), stderr surfaces in the TUI, and a non-zero exit reads as a
  hook error. `claude-sound` therefore swallows the failure of a player that is
  installed but has no audio server to reach, which is every headless VM.
- The `deny` list in `settings.json` stays thin on purpose. `claude-rm-scope-check`
  decides whether an `rm` escapes the work area, so `deny` keeps only the
  never-in-scope catastrophic backstops it can't reason about.

### Hook Self-Tests

A hook with non-trivial matching or side effects carries its own tests, gated on the
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

- **Bash hooks** embed a block right after the `set` line, before reading stdin. A
  matching hook defines a `t <want-exit> <command>` helper that re-invokes the hook
  (`CLAUDE_HOOK_SELFTEST= "$0"`) with a crafted `{tool_input:{command:…}}` payload and
  asserts the exit code; `claude-http-server-bind-check` is the copy-paste template.
  Where branches share an exit code, assert the side effect instead: `claude-stop`
  stubs the checks and announcers it calls on PATH and compares the set that recorded
  a call, which is what distinguishes a check that blocked from one that passed when
  both exit 0. Where the exit code is the same across branches
  but what the hook says differs, assert on the text: `claude-gh-status` exits 0 whether
  or not it has anything to report, so its helpers capture the output and match a
  substring that only the branch under test prints.
- **Python hooks** check the env var in `main()` and run an embedded case matrix
  against a pure `(command, cwd, repo_root) -> …` function, so the tests need no git
  or filesystem. See `claude-rm-scope-check`.
- External state is a reason to stub, not a reason to skip. Where a hook consults the
  world through PATH, a stub directory prepended to PATH is enough, and any variable
  whose ambient value would decide a case has to be unset in the test environment.
  Where a hook needs a specific git repo,
  building one with `git init` in a `mktemp -d` sandbox and `cd`-ing into it before
  re-invoking the hook is enough: `claude-git-dash-c-check` does this to test
  blocking on the repo root, on `.`, and from a subdirectory, while allowing a
  different repo. `claude-uv-check` uses the same sandbox, `touch`-ing a `uv.lock`
  in one repo and not the other so the fixture covers both the "not a uv project"
  and "python invoked directly" branches. Run from a `git commit` hook, git's own
  `GIT_DIR` and `GIT_INDEX_FILE` would point every sandbox back at this clone,
  so `claude-hook-selftests` clears them before running anything; a self-test
  reached only through it needs no guard of its own.
- The installed environment is ambient state too, and CI has none of it: no `dotfiles/bin`
  on PATH and no gitconfig, so a hook that calls a sibling script by name reaches nothing
  and its guard clause passes every case. A hook that shells out to `bin/` prepends its own
  directory to PATH in the self-test (`claude-uv-check`), and a `bin/` script spells out the
  git plumbing rather than using a gitconfig alias (`is-uv-project`, `is-pre-commit-project`
  call `git rev-parse --show-toplevel`, not `git root`). Both failures are invisible locally,
  where PATH and gitconfig are installed, so a green local run says nothing about either.
- A passing self-test that cannot fail is worth nothing, so confirm a new case catches
  a deliberately broken copy of the hook before trusting it.

## Claude Code Shell Prefix

`CLAUDE_CODE_SHELL_PREFIX` in `claude/settings.json` names `bin/claude-shell`,
and Claude Code runs every Bash tool command, every hook, and every stdio MCP
server through it, handing over the whole command as one argument. Settings
hot-reload, so a change to the prefix reaches running sessions too, and a broken
`claude-shell` breaks every Bash call and every hook at once. Read and Edit do
not go through it, so a session can still repair it.

Its job today is memory. Without swap, a runaway command does not get
OOM-killed: the kernel evicts page cache, every process on the box refaults its
own code, and the VM thrashes until it is unreachable. On a systemd machine
`claude-shell` puts each command in a scope inside `claude-work.slice`, which
`do_claude_work_slice` in `install.sh` caps as a percentage of RAM. The cap
leaves room for what is _not_ in the slice, the Claude Code processes
themselves, zellij, and your own shells, so the session that started a runaway
stays responsive enough to explain the exit 137 and fix the cause. It is on the
slice rather than on each scope because a cap only has to protect the headroom,
and a slice-wide one also stops several agents' commands crowding it out together.

`systemd-run --scope` execs in place, so the command keeps the caller's working
directory, environment, standard streams, exit status, and PID, and Claude Code
stopping it reaches it directly. Commands typed into a pane by hand and the
Claude Code processes themselves are both outside the cap.

The prefix is the one place every command Claude runs passes through, so it is
where anything else about running them belongs. Filtering output through it, such
as the masking `claude-redact-secrets` does as a hook, has to account for the
stdio MCP servers that pass through it too, whose stdout is a JSON-RPC stream
rather than output to rewrite.

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
  drive. Start a new one from the closest: `pick-kube` for a one-shot pick,
  `manage-ports` for a live list.
- Python scripts in `bin/` run under `uv`, not the system interpreter. Use the
  [PEP 723](https://peps.python.org/pep-0723/) inline-script shebang
  `#!/usr/bin/env -S uv run --quiet --script` followed by a `# /// script` metadata
  block declaring `requires-python` (and `dependencies` if any), so the script is
  self-contained and reproducible. `count-claude-tokens` is the exemplar with
  third-party dependencies; the Python hooks (`claude-rm-scope-check`,
  `claude-gh-api-check`) use the same shebang with an empty dependency set. `--quiet`
  keeps `uv`'s own output off stdout, which matters for hooks whose stdout must stay
  clean (parseable JSON or empty). Every one of them is a short-lived command, which
  is what makes that shebang safe here: a `uv run` holds a shared lock on the uv cache
  for its whole life, so anything long-lived would need `--no-cache` to keep from
  blocking every `uv cache prune` on the machine.
- Shell scripts use 2-space indentation (enforced by beautysh via pre-commit)
- Target files in `targets/` are auto-sorted by the `file-contents-sorter` pre-commit hook
- Pre-commit hooks run via [pre-commit.ci](https://pre-commit.ci) on push; see
  `.pre-commit-config.yaml` for the set. pre-commit.ci skips `claude-hook-selftests`
  (it needs a real dev environment), so the `.github/workflows/pre-commit.yml`
  workflow runs the full suite (self-tests included) on push and PRs. Dependabot
  keeps the workflow's actions updated.
- The `exists` helper function (from `sources/exists.sh`) is used throughout to check command availability before use
