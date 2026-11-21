#!/usr/bin/env bash

# By absolute path, not by name: sources/ loads before commonrc-pre puts bin/ on
# PATH, so nothing here can call a bin script the way a hook or a prompt would.
"$DOTFILES/bin/is-exe-dev" || return 0

# Route gh through the GitHub integration so private repos work without a
# token ever landing on the VM, unless this box has its own `gh auth login` for
# github.com. The integration covers only the repos attached to it, and none of
# the account-level API (creating repos, forks, gists, search), so a box worked
# on by hand logs in instead. Read from gh's hosts file rather than asking gh,
# since this runs at every shell startup.
if ! grep -qs '^github\.com:' "${GH_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/gh}/hosts.yml"; then
  export GH_HOST=github.int.exe.xyz
fi

# Zellij puts its session sockets under $XDG_RUNTIME_DIR when that is set and
# falls back to /tmp/zellij-$UID when it isn't. sshd here leaves it unset while a
# systemd user unit always has it, so the zellij-session unit and the logins it
# exists to serve would otherwise build two separate sessions of the same name
# and neither would see the other. Pinning it settles the location by choice
# rather than by which context happened to start zellij first. The zellij units
# start zellij through a login shell, so this one export reaches them too.
export ZELLIJ_SOCKET_DIR="/tmp/zellij-$(id -u)"
