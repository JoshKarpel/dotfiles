---
name: zellij
description: >
  Work with zellij, the terminal multiplexer: `config.kdl` options and
  keybindings, layouts and swap layouts, `zellij action` / `run` / `subscribe`
  scripting of tabs and panes, session resurrection, the web client
  (`zellij web`), plugins, and upgrades. Grounds answers in the installed
  binary's own help, the current docs source, and zellij's source at the
  installed tag, plus a list of gotchas earlier sessions paid for. MUST be
  invoked whenever zellij comes up: answering how zellij works, editing
  `config.kdl` or a layout, adding or debugging a keybinding, writing a script
  or hook that calls `zellij action` (renaming tabs, opening panes, reading
  `list-tabs --json`), probing zellij behavior empirically, debugging a pane's
  environment, TERM, cwd, or a resurrected session, or debugging the zellij web
  client in a browser.
allowed-tools: Bash(curl -sS https://raw.githubusercontent.com/zellij-org/*)
---

# zellij

Zellij changes behavior between minor releases, and past sessions have been
wrong from memory about flag names, defaults, and what reloads live. Establish
facts from the sources below, in roughly this order, and probe anything a
change depends on (see "Probe in a throwaway session").

## Sources of truth

**The installed binary** says what this version actually accepts:

```bash
zellij --version
zellij action help <subcommand>     # also: zellij help run, zellij help web
zellij setup --dump-config           # every option, with its default, commented
zellij setup --dump-layout default   # the built-in layout (tab-bar, pane, status-bar)
zellij setup --check                 # config/layout/plugin/cache dirs in use
zellij action dump-layout            # the live session as KDL, every tab and floating pane
```

To see what a key does by default before taking it, search the dump:
`zellij setup --dump-config | rg -n '"Alt j"'`.

**The docs.** zellij.dev renders them as HTML only, but the markdown source is
in the website repo, and that repo is updated per release (its commits read
"doc updates for 0.45.1"). The index is
`https://raw.githubusercontent.com/zellij-org/zellij-org.github.io/main/docs/src/SUMMARY.md`,
and each page is the same path with its own filename:

```bash
curl -sS https://raw.githubusercontent.com/zellij-org/zellij-org.github.io/main/docs/src/programmatic-control.md
```

Pages range from 3KB to 100KB (`cli-actions.md`, `plugin-api-commands.md`), so
searching within the large ones is fine. For a question that spans the corpus,
sync a local copy and search that; the script prints the directory and reports
which release the docs describe next to the installed version:

```bash
rg -n 'start_suspended' "$(${CLAUDE_SKILL_DIR}/scripts/sync-docs)"
```

`programmatic-control.md` and `cli-recipes.md` are the pages for scripting
zellij from outside; `options.md` and `session-resurrection.md` for config.
The docs are good on concepts and thin on edge behavior: almost every gotcha
below was settled from `--help`, the source, or a probe, never from a page.

**The source at the installed tag**, for behavior the docs don't state:

```bash
gh api "repos/zellij-org/zellij/contents/<path>?ref=v$(zellij --version | cut -d' ' -f2)" -q .content | base64 -d
```

Files that have answered questions before: `zellij-server/src/pty.rs`
(layout metadata, command discovery), `zellij-utils/src/session_serialization.rs`,
`zellij-utils/src/input/options.rs`, `zellij-client/src/cli_client.rs`, and the
web client's JS in `zellij-client/assets/`. Search issues with
`gh api -X GET search/issues -f q='repo:zellij-org/zellij <terms>'` before
calling something a bug.

## Driving zellij from inside the live session

A Claude Code shell is usually a pane in the user's own session (`ZELLIJ`,
`ZELLIJ_SESSION_NAME`, and `ZELLIJ_PANE_ID` are set), so a bare `zellij action`
acts on what the user is looking at.

- **Target by id, not by focus.** `rename-tab NAME` renames the *focused* tab,
  not the caller's; use `rename-tab --tab-id`. Find the caller's own tab from
  `$ZELLIJ_PANE_ID` via `list-panes --json --tab`, filtering
  `.is_plugin == false`: terminal and plugin pane ids are numbered separately
  and collide.
- `tab_id` is stable; `position` is not, and `go-to-tab N` is 1-based. Prefer
  `go-to-tab-by-id`, `close-tab-by-id`, `rename-tab-by-id`.
- `new-tab` prints the new tab's id and, without `--no-focus`, switches the
  user's view to it.
- `zellij --layout FILE ...` from inside a session adds tabs to the *current*
  session rather than starting a new one. Strip the variables first:
  `env -u ZELLIJ -u ZELLIJ_SESSION_NAME -u ZELLIJ_PANE_ID zellij ...`.
- With no session in the environment and several running, `zellij action`
  prints "Please specify the session name" and **exits 0**. Pass `-s <name>`
  explicitly in scripts.
- `list-tabs --json` occasionally exits 0 with empty stdout (the client returns
  on whichever of the server's unblock or its output arrives first). Callers
  that parse it retry, or treat empty as "try again on the next event".
- Piping a listing into `head` makes zellij panic with "Broken pipe" (still
  exit 0). Capture the output, then slice it.
- Timings, measured: `list-tabs` ~20ms, `rename-tab` ~20ms, `list-panes --json`
  ~250ms. A hook that runs per tool call caches what it looks up with
  `list-panes`.

## Probe in a throwaway session

Never experiment against the user's session. This isolates a probe completely:

```bash
mkdir -p /tmp/claude-$UID/zjp
env -u ZELLIJ -u ZELLIJ_SESSION_NAME -u ZELLIJ_PANE_ID ZELLIJ_SOCKET_DIR=/tmp/claude-$UID/zjp \
  zellij [--config copy.kdl] attach --create-background probe
# ... zellij -s probe action ..., with the same env ...
zellij delete-session --force probe   # kill-session alone leaves it resurrectable
rm -r /tmp/claude-$UID/zjp
```

Every command in the probe needs the same `env` prefix, or it reaches the
user's session instead. The forced delete prints "Session not found" after
killing; that is cosmetic.

- **Keep the socket directory short.** The socket path is capped at 107 bytes,
  and the error for exceeding it ends in a misleading
  "session name must be less than 0 characters". A scratchpad path is usually
  too long.
- **Under a different socket directory the user's live session lists as
  `EXITED - attach to resurrect`**, because resurrection state lives in the
  shared cache dir. Attaching to it from there starts a second copy. Never
  attach to a session you didn't create in the probe.
- **A background session with no client is not a faithful model.** Tabs are
  never laid out (0x0 viewport, empty `dump-layout` body, panes missing from
  `list-panes`), plugins don't load ("No connected clients found" in the log),
  and `override-layout` silently does nothing. Attach a client through a pty:
  `script -qfc "stty cols 120 rows 40; zellij attach probe" /dev/null < <(sleep 60) &`,
  or Python `pty.fork()` with `TIOCSWINSZ` when you need to send keys.
- **Keybindings can only be tested through a pty client**, by writing the raw
  bytes (`\x1be` is Alt+e, `\x1bE` is Alt+Shift+e, `\x14` is Ctrl+t). No CLI
  action fires a binding.
- `zellij setup --check` (or `zellij --config f.kdl setup --check`) proves KDL
  syntax only: a bogus option name inside `Run {}` still reports
  "Well defined".
- The log is `/tmp/zellij-$UID/zellij-log/zellij.log`; layout failures such
  as "Not enough room for panes" show only there.

## Config and keybindings

- **Panes inherit the server's environment, not the attaching client's.** A
  server started by a systemd unit gives panes no `TERM` (Claude Code then
  falls back to `dumb`, and `less` warns "terminal is not fully functional").
  The `env { TERM "..." }` block in `config.kdl` fixes it, but only a CLI client
  applies that block to the server it spawns; `zellij web` does not. A
  resurrected command pane is a direct child of the server with no shell, so no
  rc file ever runs in it.
- **Live reload is uneven; verify per option.** Keybinding edits and the
  `web_client` font reached running sessions; `post_command_discovery_hook`
  did not; `zellij web` serves the config it read at startup to newly loaded
  pages. When in doubt, the change applies on the next server start.
- `pane_frames` defaults to on, but the default `pane_frame_style "titles"`
  draws only a title row with no border; `"full"` draws borders. A runtime
  toggle lasts only as long as the server.
- An uppercase letter means Shift: `bind "Alt E"` is Alt+Shift+e. A binding
  takes the key from every pane in every mode it covers, so check readline and
  the defaults first (Ctrl+e is end-of-line, Ctrl+y is yank).
- `Run "prog" "arg"` passes arguments to the program directly, with no shell:
  use `Run "bash" "-c" "..."` for pipes or `||`, and call scripts by full name
  (shell aliases don't exist there). A `Run` pane starts in the focused pane's
  cwd and gets the server's `PATH`.
- `close_on_exit true` closes the pane before an error can be read; wrap as
  `bash -c "cmd || read -rsn1 -p 'cmd failed; press any key'"`.
- **Opening any floating pane reveals the tab's hidden floating panes** and
  leaves them showing after it closes. Pickers and popups use `in_place true`
  instead. Follow a `Run` binding with `SwitchToMode "normal"` so that, when
  pressed from another mode, typed keys reach the new pane.
- Fullscreen (`ToggleFocusFullscreen`) does nothing in a tab with one tiled
  pane; floating panes don't count.

## Layouts

- A layout is a template applied at session start, `new-tab --layout`, or
  `override-layout`; afterwards nothing ties the tab to it. The tab bar and
  status bar are plugin panes *in the layout*, so a tab opened with a one-pane
  layout has no bars.
- **A resurrected session's `new_tab_template` pins an absolute `cwd`, which
  overrides `new-tab --cwd`.** Pass `--layout default` (the built-in) alongside
  `--cwd` to get both bars and the requested directory.
- A nested `--layout-string` written on one line failed to parse where the
  same layout split one `pane` per line worked.
- `override-layout` drops panes that don't fit unless given
  `--retain-existing-terminal-panes`.

## Session resurrection

- State is at `~/.cache/zellij/contract_version_<N>/session_info/<session>/session-layout.kdl`.
  `zellij action dump-layout` runs the same serialization, so it shows what a
  resurrection will restore without waiting for the save (every 60s by default).
- A pane that was running a command is saved with `start_suspended true`, which
  is the "Press ENTER to run" banner. `attach --force-run-commands` skips it.
- `post_command_discovery_hook "true"` records no command, so panes come back
  as plain shells. In 0.45 that costs floating panes their cwd: a floating
  pane's cwd is serialized only as part of its command, so it comes back in the
  session root.
- Socket and cache directories are keyed by protocol contract version, not
  zellij version. After an upgrade the old server keeps running its deleted
  binary, and a newer CLI can still reach it until the contract changes;
  mismatched versions log "Received unknown message from client".

## Web client

- The browser takes Ctrl+T, Ctrl+N, and Ctrl+P before the page sees them, so
  modes on those keys need Alt alternates for web use.
- A bare Esc reaches non-kitty-protocol panes as an empty write
  (zellij-org/zellij#5190, from 0.44.2). Workaround: in normal and locked mode,
  `bind "Esc" { Write 27; }`.
- Any touch-capable device (including Windows laptops with `pointer: coarse`)
  routes keys into a hidden mobile capture input, so chords go to the browser
  (#5722). `window.__zjSoftKbdEnabled = false` in the console disables it until
  reload.
- `web_client { font "..." }` is a CSS font list handed to xterm.js; zellij
  ships no font files, so the font must be installed where the browser runs.
  The terminal draws to a canvas, so check `window.term.options.fontFamily`,
  not element CSS.
- Tokens: `zellij web --create-token` shows the value once;
  `--create-read-only-token` can't take `--token-name`. A temporary read-only
  token, used with `curl` against `POST /command/login` and then revoked, lets
  you inspect what the server sends a browser without the user's token.
- `zellij web --status` reports offline for a moment after a restart.

## Upgrading or building

Upstream publishes no nightlies: releases come from `v*` tags only, and CI
keeps no artifacts from main. Running main means building it. With mise's cargo
backend the workspace needs the crate named:
`"cargo:https://github.com/zellij-org/zellij" = { version = "rev:<sha>", crate = "zellij" }`.
Release builds embed the plugin wasm, so no separate plugin build is needed.
A new binary reaches a running session only through a server restart, which
ends every pane.

## In the dotfiles repo

This setup's choices are documented where they live: the comments in
`config/zellij/config.kdl` say why each deviation from the defaults exists, and
`CLAUDE.md` "The Work Session" covers the systemd units, socket pinning, and
`zellij-restart-session`. Read those before changing either, rather than
re-deriving them.
