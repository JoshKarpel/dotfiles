#!/usr/bin/env bash

# This machine's own session: one per box, named after its short hostname, which
# zellij renders in the top-left corner so every window says which box it is on.
# The name also titles the push notifications, which take it from
# $ZELLIJ_SESSION_NAME.
#
# On a dev box the zellij-session unit creates that session at boot, which is
# what makes it outlive the last logout rather than only the last dropped
# connection. Nothing here decides whether it exists; this end only joins it,
# and only when asked to. A login lands at a prompt: `za` from a terminal, or
# the atlas link to the web client, is how you get in. A tool that opens a shell
# for its own purposes (VS Code resolving its environment, an editor terminal,
# `ssh <vm> <command>`) therefore gets a plain shell rather than a client
# attached to the session someone is looking at elsewhere.

# A shell reaches a server only through a socket file, so a server whose socket
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
# the work is missing. commonrc-post calls this at the end of startup, where the
# message survives on screen: `za` hands the terminal to zellij immediately, so
# anything printed there is gone by the time it could be read.
function warn_stranded_zellij_servers() {
  local session pid flag socket

  # Only exe.dev pins the socket directory, and without one there is nothing to
  # judge a socket against.
  [[ -n ${ZELLIJ_SOCKET_DIR:-} ]] || return 0
  exists pgrep || return 0

  session=$(hostname -s)

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
    echo "zellij: which this shell cannot reach. Attaching starts a second one." >&2
    echo "zellij: Its panes are still running and cannot be reattached." >&2
    echo "zellij: Inspect with 'ps --ppid $pid'; 'kill $pid' when done." >&2
  done
}

# `z` is zellij itself, for the subcommands (`list-sessions`, `delete-session`,
# `action`) that have nothing to do with the machine's own session.
alias z=zellij

# `za` joins that session. A function rather than an alias so the already-inside
# check and the client eviction below have somewhere to live.
#
# --create rather than a bare attach, though on a dev box the zellij-session
# unit has almost always created it already. That unit returns before the
# session registers, so a login racing the boot would find nothing to attach to,
# and a box that is on exe.dev without being a dev box has no unit at all. One
# invocation covers both without a branch. A bare `zellij` would instead invent
# a fresh auto-named session and leave it behind on every invocation, which is
# where stray sessions come from.
#
# No --layout: the built-in default is what a bare `zellij` gives, and it tracks
# upstream as zellij is upgraded. A custom layout here is a dumped copy of
# today's default, so it would freeze that and needs shipping to every VM to
# work at all.
#
# No exec: a detach returns to the shell it was typed in, rather than ending the
# login along with it.
function za() {
  local session

  # Zellij declines to nest, but the eviction below would not: run from inside
  # the session, it matches this client's own attach and drops the caller.
  if [[ -n ${ZELLIJ:-} ]]; then
    echo "za: already attached to '${ZELLIJ_SESSION_NAME:-a zellij session}'" >&2
    return 1
  fi

  session=$(hostname -s)

  # Zellij sizes a session to the smallest attached client and keeps a client
  # registered until its process dies, so a window that is gone but unreaped
  # (a dropped ssh, a closed exe.dev web terminal) silently shrinks the session
  # for whoever is actually looking at it. Zellij has no `attach --detach-others`
  # and no per-client action at all, so evict them here. This is not destructive:
  # the server and every pane outlive their clients, and a live client that gets
  # kicked drops back to the shell it was started from.
  #
  # This reaches terminal clients only. The browser client is a connection
  # inside the web server process rather than a process of its own, so a
  # forgotten tab is not something pkill can see.
  #
  # SIGKILL rather than SIGTERM: a client whose terminal is already gone blocks
  # forever writing to it on the way out, so SIGTERM leaves the process alive to
  # accumulate, which is precisely the case being cleaned up here.
  #
  # No match is the ordinary case, so the failure is swallowed.
  pkill -9 -u "$(id -u)" -f "^zellij attach --create $session\$" || true

  zellij attach --create "$session"
}
