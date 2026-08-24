#!/usr/bin/env bash

BASEDIR="$(dirname "$(realpath "$0")")"

function exists_and_not_symlink() {
  [[ (-e $1) && (! -L $1) ]]
}

function log() {
  printf "\n\033[0;30;46m$1\033[0m\n"
}

function do_config() {
  BACKUPS=~/.dotfiles-backups

  log "Creating symlinks in $HOME for files in dotrc/ and config/ ..."

  DOTRC=$BASEDIR/dotrc
  for file in "$DOTRC"/*; do
    [[ -f $file ]] || continue

    target=~/."$(basename "$file")"

    if exists_and_not_symlink "$target"; then
      mkdir -p $BACKUPS
      backup=$BACKUPS/"$(basename "$target")"
      echo "mv $target -> $backup"
      mv $target $backup
    fi

    echo "link $target -> $file"
    ln -sf "$file" "$target"
  done

  touch ~/.gitconfig-local

  CONFIG=$BASEDIR/config
  mkdir -p "$CONFIG"
  mkdir -p ~/.config
  for dir in "$CONFIG"/*; do
    target=~/.config/"$(basename "$dir")"
    echo "link $target -> $dir"
    ln -nsf "$dir" "$target"
  done

  "$BASEDIR/bin/link-claude"
}

function do_ssh_key() {
  local key=~/.ssh/id_ed25519

  log "Setting up SSH key..."

  if [[ -f $key ]]; then
    echo "SSH key already exists at $key"
    return 0
  fi

  mkdir -p ~/.ssh
  chmod 700 ~/.ssh

  # No passphrase: this key is used unattended (git over SSH, exe.dev), and a
  # prompt would hang the first-boot bootstrap that has no terminal to ask on.
  ssh-keygen -t ed25519 -N "" -C "$(whoami)@$(hostname)" -f "$key"
}

function do_apt() {
  if ! exists apt-get; then
    return 0
  fi

  log "Updating apt targets..."

  sudo apt-get update

  # add-apt-repository ships in software-properties-common, which is itself one
  # of the targets, so the PPA can only be added once the targets are in.
  xargs -r -a "$BASEDIR/targets/apt.txt" -- sudo apt-get install -y

  # add-apt-repository refreshes the package lists itself (that's what makes the
  # newer git visible to the upgrade below), so re-adding a PPA that's already
  # configured buys a full refresh and nothing else.
  if ! grep -rqs "git-core/ppa" /etc/apt/sources.list /etc/apt/sources.list.d/; then
    sudo add-apt-repository ppa:git-core/ppa -y
  fi

  sudo apt-get upgrade -y
  sudo apt-get autoremove -y

  # The .debs the upgrade just downloaded are dead weight once installed. Here
  # rather than in bin/tidy, so that stays user-level and never needs a password.
  sudo apt-get clean
}

function do_locale() {
  if ! exists locale-gen; then
    return 0
  fi

  log "Updating locale..."

  if ! locale -a | grep -q "^en_US.utf8$\|^en_US.UTF-8$"; then
    sudo localedef -i en_US -f UTF-8 en_US.UTF-8
    sudo locale-gen "en_US.UTF-8"
  else
    echo "Locale en_US.UTF-8 already generated"
  fi
}

function do_brew() {
  if ! [[ $(uname) == "Darwin" ]]; then
    return 0
  fi

  if ! exists brew; then
    log "Installing brew..."

    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi

  log "Updating brew targets..."

  brew update

  brew install --display-times findutils  # BSD xargs doesn't have -a
  path_prefix "$(brew --prefix)/opt/findutils/libexec/gnubin"

  xargs -r -a "$BASEDIR/targets/brew.txt" -- brew install --display-times

  brew upgrade

  # --prune=all drops the whole download cache rather than only aged entries.
  brew cleanup --prune=all

  "$(brew --prefix)"/opt/fzf/install --completion --key-bindings --no-update-rc
}

function do_mise() {
  if ! exists mise; then
    log "Installing mise..."
    curl https://mise.run | sh
  fi

  log "Updating mise tools..."

  "$HOME/.local/bin/mise" install
  "$HOME/.local/bin/mise" upgrade
}

# `systemctl --user` finds its manager through XDG_RUNTIME_DIR, which a login
# shell has and the first-boot bootstrap running install.sh over `ssh host
# <command>` does not. Without it every call fails with "Failed to connect to
# bus: No medium found", which reads as systemd being absent and is really the
# environment being thin.
function use_user_bus() {
  if [[ -z ${XDG_RUNTIME_DIR:-} ]]; then
    export XDG_RUNTIME_DIR="$(loginctl show-user "$(id -un)" --value -p RuntimePath)"
  fi
}

# Schedules bin/cloister-codex, which does the work of serving this machine's
# sessions and is where the dev-box guard lives. This only sets up the timer that
# fires it once a day, then runs it once so the box is serving now rather than
# whenever the timer first comes round.
function do_cloister() {
  local units=~/.config/systemd/user

  # cloister-codex guards itself on the same test, which is what makes it safe to
  # run by hand anywhere. This one is earlier because a laptop has neither
  # systemctl nor loginctl for the rest of this function to call.
  "$BASEDIR/bin/is-dev-box" || return 0

  use_user_bus

  log "Scheduling the cloistered codex..."

  mkdir -p "$units"

  # Written rather than symlinked out of config/: the unit has to name the clone
  # this ran from, and only install.sh knows where that is.
  cat > "$units/cloister-codex.service" << EOF
[Unit]
Description=Update claude-scriptorium and converge the cloistered codex

[Service]
Type=oneshot
ExecStart=$BASEDIR/bin/cloister-codex
EOF

  # Persistent catches up a run the box was shut down for, which is the ordinary
  # case for a devbox rather than the exception. The randomised delay is why the
  # window is a day rather than a fixed minute: every box would otherwise reach
  # for the same release at the same instant.
  cat > "$units/cloister-codex.timer" << EOF
[Unit]
Description=Keep the cloistered codex on the latest published claude-scriptorium

[Timer]
OnCalendar=daily
Persistent=true
RandomizedDelaySec=1h

[Install]
WantedBy=timers.target
EOF

  systemctl --user daemon-reload
  systemctl --user enable --now cloister-codex.timer

  "$BASEDIR/bin/cloister-codex"
}

# Runs bin/exe-dev-atlas on 8000, the port the bare `https://<vm>.exe.xyz/`
# hostname is proxied to, so the box's front door is an index of everything else
# worth opening rather than any one of those things.
function do_exe_dev_atlas() {
  local units=~/.config/systemd/user

  "$BASEDIR/bin/is-dev-box" || return 0

  use_user_bus

  log "Serving the atlas..."

  mkdir -p "$units"

  # A daemon rather than a converge job, so unlike cloister-codex there is no
  # timer: the unit is the whole of it.
  #
  # The PATH is spelled out because a user unit inherits none of a login shell's,
  # and the script's `uv run` shebang has to resolve `uv` through mise's shims.
  # Restart=always covers the scan thread dying on a kernel interface that
  # answered differently than it used to; there is nothing to lose by starting
  # over, and a box whose front door 502s is one nobody can navigate.
  cat > "$units/exe-dev-atlas.service" << EOF
[Unit]
Description=Index this VM's ports, sessions, and workspaces on the default hostname

[Service]
ExecStart=$BASEDIR/bin/exe-dev-atlas
Environment=PATH=%h/.local/share/mise/shims:%h/.local/bin:/usr/local/bin:/usr/bin:/bin
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

  systemctl --user daemon-reload
  systemctl --user enable exe-dev-atlas.service

  # Unconditionally, rather than `enable --now`: the file above may have changed
  # under a service that is already running, and a daemon this cheap to start has
  # no work in flight worth preserving.
  systemctl --user restart exe-dev-atlas.service
}

# Owns the box's work session, so that it exists because the box is up rather
# than because somebody logged in. Without this the session is created lazily by
# the first interactive login, which means a reboot silently discards it until
# someone reconnects.
#
# `attach --create-background` is the only way in to a session without a
# controlling terminal: every other form of `attach` wants raw mode and panics
# without it. It leaves no client registered behind it, so converging this unit
# never shrinks the session the way an unreaped terminal client would, and the
# usual "never restart an active oneshot" caution does not apply.
#
# It exits 1 with "Session already exists" rather than succeeding as a no-op,
# which for a unit whose job is to converge on "the session exists" is success.
# SuccessExitStatus is narrow enough to say so: a real failure panics and exits
# 101, so tolerating 1 does not swallow one.
#
# Note that it returns before the session registers, so nothing may order itself
# after this unit expecting the session to be there. The `za` function handles
# that race by running `attach --create` rather than a bare `attach`.
#
# %l is the short hostname, matching what sources/zellij.sh computes, so the
# unit names no box and survives a rename.
#
# ZELLIJ_SOCKET_DIR is pinned to the same path sources/exe.sh pins, and for the
# reason given there: a unit has XDG_RUNTIME_DIR and a login here does not, so
# left alone the two build separate sessions of the same name.
function do_zellij_session() {
  local units=~/.config/systemd/user

  "$BASEDIR/bin/is-dev-box" || return 0

  use_user_bus

  log "Converging the work session..."

  mkdir -p "$units"

  # RemainAfterExit so the unit reads as active while the session it created is
  # up, rather than as a job that ran once and finished.
  cat > "$units/zellij-session.service" << 'EOF'
[Unit]
Description=Keep this box's zellij work session running

[Service]
Type=oneshot
RemainAfterExit=yes
SuccessExitStatus=1
Environment=ZELLIJ_SOCKET_DIR=/tmp/zellij-%U
ExecStart=%h/.local/share/mise/shims/zellij attach --create-background %l

[Install]
WantedBy=default.target
EOF

  systemctl --user daemon-reload
  systemctl --user enable --now zellij-session.service
}

# Serves the work session over HTTPS at `https://<vm>.exe.xyz:3000/<session>`.
# The port comes from `web_server_port` in config/zellij/config.kdl rather than a
# flag here, so the CLI and this unit agree on where the server is.
#
# The server binds loopback and speaks plain HTTP: exe.dev terminates TLS at the
# proxy, so a certificate on the VM would be a second thing to obtain and rotate
# for no gain. The web client derives its own `wss://` URL from window.location,
# so it needs no telling that it is behind a terminator.
#
# Two independent gates sit in front of this, and both are load-bearing. The
# exe.dev proxy is private by default, so an unauthenticated request is bounced
# to an exe.dev login. Zellij then wants its own token, minted per box with
# `zellij web --create-token` and shown exactly once. Do not `share set-public`
# this port: that would drop the first gate and leave an interactive shell behind
# nothing but the token.
function do_zellij_web() {
  local units=~/.config/systemd/user

  "$BASEDIR/bin/is-dev-box" || return 0

  use_user_bus

  log "Serving the work session over HTTPS..."

  mkdir -p "$units"

  # A daemon rather than a converge job, so like the atlas there is no timer.
  # Restarting it is safe at any time: sessions live in their own processes and
  # outlive this one, which only brokers connections to them.
  cat > "$units/zellij-web.service" << 'EOF'
[Unit]
Description=Serve zellij sessions over the exe.dev HTTPS proxy

[Service]
ExecStart=%h/.local/share/mise/shims/zellij web
Environment=PATH=%h/.local/share/mise/shims:%h/.local/bin:/usr/local/bin:/usr/bin:/bin
Environment=ZELLIJ_SOCKET_DIR=/tmp/zellij-%U
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

  systemctl --user daemon-reload
  systemctl --user enable zellij-web.service

  # Unconditionally, for the same reason as the atlas: the file above may have
  # changed under a running server, and there is no work in flight to preserve.
  systemctl --user restart zellij-web.service
}

# Serves VS Code in the browser at `https://<vm>.exe.xyz:3001/`, alongside the
# Remote-SSH path rather than instead of it. The two differ in where the
# workbench runs, and that decides where its settings come from: Remote-SSH runs
# it on the laptop and picks up the settings already there, while this runs it
# here and keeps them in the browser's own storage, which is why it needs
# Settings Sync signed in per browser and the desktop path does not.
function do_vscode_web() {
  local units=~/.config/systemd/user

  "$BASEDIR/bin/is-dev-box" || return 0

  use_user_bus

  log "Serving VS Code over HTTPS..."

  mkdir -p "$units"

  # No connection token, matching the codex and the atlas: the server binds
  # loopback and the exe.dev proxy is private, so the only way to it is through
  # an exe.dev login or a tunnel by someone who already has a shell. A token
  # would also have to ride in the query string, which would break the plain
  # `:3001/` link the atlas offers.
  #
  # This one does hand out a terminal, so unlike those two it is a shell. Never
  # `share set-public` this port. Only one port per VM can be public and the
  # atlas holds it, so that would take deliberately dislodging the atlas first.
  cat > "$units/vscode-web.service" << 'EOF'
[Unit]
Description=Serve VS Code in the browser over the exe.dev HTTPS proxy

[Service]
ExecStart=%h/.local/share/mise/shims/code serve-web --host 127.0.0.1 --port 3001 --without-connection-token --accept-server-license-terms
Environment=PATH=%h/.local/share/mise/shims:%h/.local/bin:/usr/local/bin:/usr/bin:/bin
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

  systemctl --user daemon-reload
  systemctl --user enable vscode-web.service

  # Unconditionally, for the same reason as the others. Editor state lives in the
  # browser and on disk rather than in this process, so a restart costs a reload.
  systemctl --user restart vscode-web.service
}

do_config

. "$HOME/.commonrc-pre"

do_ssh_key
do_apt
do_locale
do_brew
do_mise
do_cloister
do_exe_dev_atlas
do_zellij_session
do_zellij_web
do_vscode_web
