#!/usr/bin/env bash

# exe.dev VMs carry the platform's own tooling at /exe.dev, which makes its
# presence the cheapest offline test for "am I on a VM rather than a laptop".
[[ -d /exe.dev ]] || return 0

# Route gh through the GitHub integration so private repos work without a
# token ever landing on the VM.
export GH_HOST=github.int.exe.xyz

# Land in zellij on arrival. Defined here but deliberately not called here:
# sources/ loads partway through commonrc-pre, so exec'ing at this point would
# replace the shell before the rest of startup ran, and zellij isn't even on
# PATH yet because mise activates after commonrc-pre returns. commonrc-post
# calls this as its last line instead.
#
# One fixed session name, attached rather than created. A dropped connection
# detaches instead of quitting, so the session outlives it; starting a fresh one
# per login would leave the surviving session behind with nothing pointing at
# it. Attaching also resurrects a session that did exit.
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
  local session=dev

  if [[ $- == *i* && -z ${ZELLIJ:-} && -t 0 && -t 1 ]] && exists zellij; then
    if zellij list-sessions --short --no-formatting 2>/dev/null | grep -qx "$session"; then
      # Zellij sizes a session to the smallest attached client and keeps a
      # client registered until its process dies, so a window that is gone but
      # unreaped (a dropped ssh, a closed exe.dev web terminal) silently shrinks
      # the session for whoever is actually looking at it. Zellij has no
      # `attach --detach-others` and no per-client action at all, so evict them
      # here. This is not destructive: the server and every pane outlive their
      # clients, and a live login that gets kicked just reconnects.
      #
      # Both invocations have to match, since whoever created the session is
      # running `--session` while everyone who came after runs `attach`.
      #
      # SIGKILL rather than SIGTERM: a client whose terminal is already gone
      # blocks forever writing to it on the way out, so SIGTERM leaves the
      # process alive to accumulate, which is precisely the case being cleaned
      # up here. Either way the server drops the client and the panes are
      # untouched, and a kicked login's terminal is restored by its own ssh.
      pkill -9 -u "$(id -u)" -f "^zellij (attach|--session) $session\$" || true

      exec zellij attach "$session"
    fi

    # No --layout: the built-in default is what a bare `zellij` gives, and it
    # tracks upstream as zellij is upgraded. A custom layout here is a dumped
    # copy of today's default, so it would freeze that and needs shipping to
    # every VM to work at all.
    exec zellij --session "$session"
  fi

  return 0
}
