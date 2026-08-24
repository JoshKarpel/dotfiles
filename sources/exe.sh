#!/usr/bin/env bash

# By absolute path, not by name: sources/ loads before commonrc-pre puts bin/ on
# PATH, so nothing here can call a bin script the way a hook or a prompt would.
"$DOTFILES/bin/is-exe-dev" || return 0

# Route gh through the GitHub integration so private repos work without a
# token ever landing on the VM.
export GH_HOST=github.int.exe.xyz

# Zellij puts its session sockets under $XDG_RUNTIME_DIR when that is set and
# falls back to /tmp/zellij-$UID when it isn't. sshd here leaves it unset while a
# systemd user unit always has it, so the zellij-session unit and the logins it
# exists to serve would otherwise build two separate sessions of the same name
# and neither would see the other. Pinning it on both sides settles the location
# by choice rather than by which context happened to start zellij first.
export ZELLIJ_SOCKET_DIR="/tmp/zellij-$(id -u)"
