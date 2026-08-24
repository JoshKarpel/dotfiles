# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal dotfiles repository. The `install.sh` script symlinks configs into place, generates an SSH key if one is missing, and installs toolchain dependencies (apt, brew, mise). mise manages node, rust (wrapping rustup), uv, and most standalone CLI tools; see `config/mise/config.toml`.

## Repository Structure

- **`dotrc/`** — Files symlinked as `~/.<filename>` (bashrc, zshrc, commonrc-pre, commonrc-post, gitconfig, etc.)
- **`config/`** — Top-level entries symlinked into `~/.config/` under their own names. An entry that is a file lands as a file, so `starship.toml` becomes `~/.config/starship.toml`, not `~/.config/starship/`. Adding a tool's config needs no change to `install.sh`.
- **`claude/`** — Source files symlinked into `~/.claude/` via `bin/link-claude`: the global `CLAUDE.md`, `settings.json`, `skills/`, `rules/`, and `output-styles/`. Anything else added here lands at the matching path under `~/.claude/`, and a symlink whose source is later deleted is pruned on the next run wherever it sits. Edit these here, not the symlinks in `~/.claude/`.
- **`sources/`** — Shell scripts sourced by `commonrc-pre` at shell startup (aliases, git helpers, path management, etc.)
- **`targets/`** — Package lists for apt and brew (one package per line, kept sorted by pre-commit)
- **`bin/`** — Scripts added to PATH via `dotfiles/bin`; add any executable scripts here and they will be available in the shell (e.g., for Claude Code hooks)

Systemd user units are the exception to `config/`. `install.sh` writes
`cloister-codex.{service,timer}`, `exe-dev-atlas.service`,
`zellij-session.service`, `zellij-web.service`, and `vscode-web.service` into
`~/.config/systemd/user/` rather than symlinking them from here, because a unit
has to name the absolute path of the clone it was installed from, and only
`install.sh` knows where that is. The same directory is where
`claude-scriptorium` writes the codex service it manages itself, so symlinking
the tree in would point that tool's writes at this repo.

All of those are for a person to look at, so all are gated on `is-dev-box`
rather than `is-exe-dev`: a VM running a workload has nobody reading its session
archive and no reason to spend its proxied ports on an index of itself. It reads
the same `dev-box` tag `exe-dev create-devbox` sets at creation, which is what
keeps a bot-box running `install.sh` on its timer from installing any of them.
Reading it back through reflection rather than off the disk is what lets a box
change its mind (`exe-dev lobby tag <vm> dev-box`) without being rebuilt.

They all depend on `Linger=yes` for the account, without which the user manager
starts at first login instead of at boot and every one of them waits for a
connection that the box exists to not need. Nothing here sets it; it comes with
the exeuntu image.

exe.dev proxies one port per VM to the bare `https://<vm>.exe.xyz/` hostname and
forwards 3000-9999 to `https://<vm>.exe.xyz:<port>/`. `exe-dev-atlas` takes the
bare hostname's port so the front door is an index of everything else. The
atlas sorts by port, so the bottom of the forwarded range is the top of the
index, and the two ways in to the box take it: the work session on 3000 and VS
Code on 3001. A dev server lands wherever it lands above those, and services that
are only occasionally opened start at 4000, where the codex is.

## The Work Session

A dev box holds one long-lived zellij session named after its short hostname.
`zellij-session.service` creates it at boot, which is what makes it outlive the
last logout rather than only the last dropped connection. Creating it from the
login shell instead would tie its existence to somebody having connected, so a
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

`exe-dev-atlas` links each session directly and deliberately does not link the port
itself: arriving at a zellij web server without a session named in the path
creates a new one, so a link to its root would leave an empty session behind on
every visit. Session names, and the Remote-SSH link to the VM, go only to its
owner, comparing the `X-ExeDev-Email` the exe.dev proxy injects (which overwrites
whatever the client sent) against the owner address from reflection. A session
name is often a project name and the atlas is reachable by anyone the VM is
shared with, so the default is to withhold: an unauthenticated caller and a
failed reflection lookup both produce an empty string, and the check requires
both sides non-empty rather than letting those compare equal. Following the VM's
actual sharing grants would be better, but reflection does not publish them.

That link opens the home directory rather than no directory. A `vscode://` URL
with no path resolves to `/` rather than to a folderless window, so the choice is
home or the whole filesystem, not home or nothing (microsoft/vscode#232345).

`vscode-web.service` is the other half of that: `code serve-web` on 3001, kept
alongside the Remote-SSH link rather than replacing it. The two differ in where
the workbench runs, which decides where its settings come from. Remote-SSH runs
it on the laptop and inherits the settings already there. `serve-web` runs it
here and keeps user settings in the browser's IndexedDB rather than on disk, so a
`settings.json` on the box is not read and Settings Sync has to be signed in per
browser. The CLI comes from mise rather than the copy Remote-SSH pushes to
`~/.vscode-server/code-<commit>`, whose path moves with every VS Code update.

Four details are worth knowing before touching any of this.

Zellij keys its session sockets off `$XDG_RUNTIME_DIR` and falls back to
`/tmp/zellij-$UID` when it is unset. A systemd user unit always has it and sshd
here never does, so the unit and the logins it exists to serve build two separate
sessions of the same name unless both pin `ZELLIJ_SOCKET_DIR`. Both do.

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

The session outlives the unit: `stop` and `restart` both leave it running, and
`install.sh` only ever `enable --now`s it. Deleting a session is
`zellij delete-session`, never `systemctl`.

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
# `update` runs this after install.sh; run it by hand to reclaim now.
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

# Install Tailscale and join this machine to the tailnet. Run per-machine, not
# from install.sh: it leaves a daemon running and joins a private network.
setup-tailscale

# Update claude-scriptorium and converge the systemd user service that serves
# this machine's sessions. Dev-box VMs only; a no-op anywhere else. install.sh
# schedules it daily, so running it by hand is only for wanting a release now.
cloister-codex

# Serve this VM's front door: proxied ports, zellij sessions, and VS Code
# workspaces, with a link to each. install.sh runs this as a systemd user service
# on the port the bare `https://<vm>.exe.xyz/` hostname reaches; run it by hand to
# serve it elsewhere.
EXE_DEV_ATLAS_PORT=9100 exe-dev-atlas

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
  per branch, and stores state under the git directory.
- A hook whose only job is a side effect still has to keep all three channels clean:
  the event decides how stdout is read (on `PreToolUse` a JSON object there is a
  permission decision), stderr surfaces in the TUI, and a non-zero exit reads as a
  hook error. `claude-notify-push` therefore discards what `curl` and `jq` would
  print, and `claude-sound` swallows the failure of a player that is installed but
  has no audio server to reach, which is every headless VM.
- `claude-notify-push` gates itself on `claude-user-away` and `is-exe-dev`, rather
  than on where it's registered. Every caller can therefore fire unconditionally, and
  the same config stays correct on a laptop, where it does nothing. An unattended
  caller that provides its own completion notification sets
  `CLAUDE_NOTIFY_PUSH_DISABLED=1` to suppress only the exe.dev push.
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
  A hook that always exits 0 has no exit code to assert, so it asserts the side effect
  instead: `claude-notify-push` stubs its downstream commands on PATH and compares the
  set that recorded a call, which is what distinguishes an early exit from a hook that
  did the work and returned 0 anyway. Where the exit code is the same across branches
  but the advice differs, assert on the message: `claude-read-check` blocks a `sed -n`
  range either way, and only the stderr text distinguishes reading a file (use Read)
  from trimming a pipe (use `head`/`tail`), so a second helper captures stderr and
  matches a substring.
- **Python hooks** check the env var in `main()` and run an embedded case matrix
  against a pure `(command, cwd, repo_root) -> …` function, so the tests need no git
  or filesystem. See `claude-rm-scope-check`.
- External state is a reason to stub, not a reason to skip. Where a hook consults the
  world through PATH, a stub directory prepended to PATH is enough, and any variable
  whose ambient value would decide a case has to be unset in the test environment
  (`claude-notify-push` unsets `CLAUDE_NOTIFY_PUSH_DISABLED` and `ZELLIJ`, both of
  which are set in a real session). Where a hook needs a specific git repo,
  building one with `git init` in a `mktemp -d` sandbox and `cd`-ing into it before
  re-invoking the hook is enough: `claude-git-dash-c-check` does this to test
  blocking on the repo root, on `.`, and from a subdirectory, while allowing a
  different repo. `claude-uv-check` uses the same sandbox, `touch`-ing a `uv.lock`
  in one repo and not the other so the fixture covers both the "not a uv project"
  and "python invoked directly" branches. What stays un-self-tested is state no
  stub stands in for: `claude-user-away` needs a terminal someone has typed into.
- The installed environment is ambient state too, and CI has none of it: no `dotfiles/bin`
  on PATH and no gitconfig, so a hook that calls a sibling script by name reaches nothing
  and its guard clause passes every case. A hook that shells out to `bin/` prepends its own
  directory to PATH in the self-test (`claude-uv-check`), and a `bin/` script spells out the
  git plumbing rather than using a gitconfig alias (`is-uv-project`, `is-pre-commit-project`
  call `git rev-parse --show-toplevel`, not `git root`). Both failures are invisible locally,
  where PATH and gitconfig are installed, so a green local run says nothing about either.
- A passing self-test that cannot fail is worth nothing, so confirm a new case catches
  a deliberately broken copy of the hook before trusting it.

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

- Python scripts in `bin/` run under `uv`, not the system interpreter. Use the
  [PEP 723](https://peps.python.org/pep-0723/) inline-script shebang
  `#!/usr/bin/env -S uv run --quiet --script` followed by a `# /// script` metadata
  block declaring `requires-python` (and `dependencies` if any), so the script is
  self-contained and reproducible. `count-claude-tokens` is the exemplar with
  third-party dependencies; the Python hooks (`claude-rm-scope-check`,
  `claude-gh-api-check`) use the same shebang with an empty dependency set. `--quiet`
  keeps `uv`'s own output off stdout, which matters for hooks whose stdout must stay
  clean (parseable JSON or empty). `exe-dev-atlas` adds `--no-cache` to that shebang
  because it runs as a service: a `uv run` holds a shared lock on the uv cache for
  its whole life, so a process that never exits blocks every `uv cache prune` on the
  machine.
- Shell scripts use 2-space indentation (enforced by beautysh via pre-commit)
- Target files in `targets/` are auto-sorted by the `file-contents-sorter` pre-commit hook
- Pre-commit hooks run via [pre-commit.ci](https://pre-commit.ci) on push; see
  `.pre-commit-config.yaml` for the set. pre-commit.ci skips `claude-hook-selftests`
  (it needs a real dev environment), so the `.github/workflows/pre-commit.yml`
  workflow runs the full suite (self-tests included) on push and PRs. Dependabot
  keeps the workflow's actions updated.
- The `exists` helper function (from `sources/exists.sh`) is used throughout to check command availability before use
