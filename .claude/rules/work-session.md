---
paths:
  - "config/zellij/**"
  - "sources/zellij.sh"
  - "sources/exe.sh"
  - "dotrc/commonrc-post"
  - "bin/zellij-*"
  - "bin/exe-dev"
  - "install.sh"
---

# The Work Session

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
panes. `TERM` and `FORCE_HYPERLINK` are the exceptions, set by `env` in
`config/zellij/config.kdl`, since zellij is the terminal its panes run in and
these say what it supports. Only a CLI client applies that
block to the server it spawns, so `zellij-web.service` pins the same values for
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

`bin/exe-dev` writes units into `~/.config/systemd/user/` too, from the setup script `create-botbox`
sends: a bot-box has nobody to run the installer on it, so it gets a timer that
does. Those name no clone (`%h` reaches the home directory, and systemd resolves
a specifier wherever it appears, quoting included), and are written at first boot
rather than on every converge, so a change to them reaches only boxes built
afterwards.
