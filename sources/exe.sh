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
      exec zellij attach "$session"
    fi

    # --new-session-with-layout, not --layout: with --session set, --layout
    # means "add these tabs to that running session" and fails when it isn't
    # there yet, which is exactly the first-login case.
    exec zellij --session "$session" --new-session-with-layout "$session"
  fi

  return 0
}
