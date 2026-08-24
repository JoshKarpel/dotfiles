#!/usr/bin/env bash

# By absolute path, not by name: sources/ loads before commonrc-pre puts bin/ on
# PATH, so nothing here can call a bin script the way a hook or a prompt would.
"$DOTFILES/bin/is-exe-dev" || return 0

# Route gh through the GitHub integration so private repos work without a
# token ever landing on the VM.
export GH_HOST=github.int.exe.xyz

# Zellij puts its session sockets under $XDG_RUNTIME_DIR when that is set and
# falls back to /tmp/zellij-$UID when it isn't. sshd here leaves it unset while a
# systemd user unit always has it, so the zellij-session unit and the login it
# exists to serve would otherwise build two separate sessions of the same name
# and neither would see the other. Pinning it on both sides settles the location
# by choice rather than by which context happened to start zellij first.
export ZELLIJ_SOCKET_DIR="/tmp/zellij-$(id -u)"

# A login reaches a server only through a socket file, so a server whose socket
# it cannot see may as well not exist: `attach --create` builds a second session
# of the same name beside it, and nothing about the new session looks wrong.
# Zellij itself guards the ordinary case, declining to clobber a live server
# whose socket is on disk even when that server is too busy to answer, so the
# gap is only the servers that fall outside this shell's view. Two ways in, both
# seen on this box: the socket file is unlinked while the server keeps running,
# and the server was started against a different socket directory, which is what
# happens whenever ZELLIJ_SOCKET_DIR is not pinned at both ends.
#
# Neither is recoverable. An unlinked socket cannot be relinked, and the panes
# live in the server's memory rather than anywhere on disk, so reporting is what
# is left. It beats the alternative, which is finding out hours later by noticing
# the work is missing.
function warn_stranded_zellij_servers() {
  local session="$1" pid flag socket

  exists pgrep || return 0

  # The loop body runs in a subshell and only prints, so nothing needs to escape
  # it; the declarations sit out here because `local` inside a pipeline is not
  # reliably scoped across shells.
  pgrep -u "$(id -u)" -x zellij 2> /dev/null | while read -r pid; do
    # `zellij --server <socket>`, so the flag is the second field and the socket
    # the last. Read from the process rather than rebuilding the path here: the
    # `contract_version_N` component is zellij's own and moves with its protocol.
    flag=$(tr '\0' '\n' < "/proc/$pid/cmdline" 2> /dev/null | head -2 | tail -1)
    socket=$(tr '\0' '\n' < "/proc/$pid/cmdline" 2> /dev/null | tail -1)

    [[ $flag == "--server" && ${socket##*/} == "$session" ]] || continue
    [[ -S $socket && $socket == "$ZELLIJ_SOCKET_DIR"/* ]] && continue

    echo "zellij: server $pid holds a session named '$session' at" >&2
    echo "zellij:   $socket" >&2
    echo "zellij: which this login cannot reach. A second one is starting." >&2
    echo "zellij: Its panes are still running and cannot be reattached." >&2
    echo "zellij: Inspect with 'ps --ppid $pid'; 'kill $pid' when done." >&2
  done
}

# Land in zellij on arrival. Defined here but deliberately not called here:
# sources/ loads partway through commonrc-pre, so exec'ing at this point would
# replace the shell before the rest of startup ran, and zellij isn't even on
# PATH yet because mise activates after commonrc-pre returns. commonrc-post
# calls this as its last line instead.
#
# One session name per VM, joined rather than started. A dropped connection
# detaches instead of quitting, so the session outlives it; starting a fresh one
# per login would leave the surviving session behind with nothing pointing at
# it. Attaching also resurrects a session that did exit.
#
# On a dev box the zellij-session unit has already created that session at boot,
# which is what makes it outlive the last logout rather than only the last
# dropped connection. This end owns joining it, not whether it exists.
#
# The name is the VM's short hostname, which zellij renders in the top-left
# corner, so every window says which box it is on. It also reaches the push
# notifications, which title themselves after $ZELLIJ_SESSION_NAME.
#
# Every guard is load-bearing:
#   - bash sources this file for remote `ssh host <command>` runs too, so
#     without the interactive test this breaks scp, rsync, and every hook.
#   - zellij panics rather than degrades when it can't get raw mode, and
#     tooling that runs `bash -lic` (VS Code resolving its environment) is
#     interactive with no tty attached, hence both -t tests.
# If zellij is ever broken, interactive logins die with it; `ssh <vm> <command>`
# skips this and is the way back in to edit it.
function start_zellij_session() {
  local session

  if [[ $- == *i* && -z ${ZELLIJ:-} && -t 0 && -t 1 ]] && exists zellij; then
    session=$(hostname -s)

    warn_stranded_zellij_servers "$session"

    # Zellij sizes a session to the smallest attached client and keeps a client
    # registered until its process dies, so a window that is gone but unreaped
    # (a dropped ssh, a closed exe.dev web terminal) silently shrinks the
    # session for whoever is actually looking at it. Zellij has no
    # `attach --detach-others` and no per-client action at all, so evict them
    # here. This is not destructive: the server and every pane outlive their
    # clients, and a live login that gets kicked just reconnects.
    #
    # This reaches terminal clients only. The browser client is a connection
    # inside the web server process rather than a process of its own, so a
    # forgotten tab is not something pkill can see.
    #
    # SIGKILL rather than SIGTERM: a client whose terminal is already gone
    # blocks forever writing to it on the way out, so SIGTERM leaves the
    # process alive to accumulate, which is precisely the case being cleaned
    # up here. Either way the server drops the client and the panes are
    # untouched, and a kicked login's terminal is restored by its own ssh.
    #
    # No match is the ordinary case, so the failure is swallowed.
    pkill -9 -u "$(id -u)" -f "^zellij attach --create $session\$" || true

    # --create rather than a bare attach, though on a dev box the
    # zellij-session unit has almost always created it already. That unit
    # returns before the session registers, so a login racing the boot would
    # find nothing to attach to, and a box that is on exe.dev without being a
    # dev box has no unit at all. One invocation covers both without a branch.
    #
    # No --layout: the built-in default is what a bare `zellij` gives, and it
    # tracks upstream as zellij is upgraded. A custom layout here is a dumped
    # copy of today's default, so it would freeze that and needs shipping to
    # every VM to work at all.
    exec zellij attach --create "$session"
  fi

  return 0
}
