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
  "$BASEDIR/bin/link-mainplate"
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

# Raises how many frames the kernel walks per perf sample. The default of 127
# truncates deeply recursive code (regex compilation goes well past it), and
# frames above the cut are lost from the profile. perf_event_paranoid stays at
# its default of 2: perf drops to user-only sampling on its own there, and
# kernel frames are a `sudo perf` away when wanted.
#
# Applying it fails with EBUSY while any perf event is open. That leaves the
# file in place for the next boot rather than aborting the install.
function do_perf_sysctl() {
  [[ -d /etc/sysctl.d ]] || return 0

  log "Raising the perf stack depth..."

  sudo tee /etc/sysctl.d/99-perf-event.conf > /dev/null << 'EOF'
kernel.perf_event_max_stack = 1024
EOF
  sudo sysctl --load=/etc/sysctl.d/99-perf-event.conf
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

  # `mise upgrade` updates the tools mise manages, never mise itself.
  log "Updating mise..."

  "$HOME/.local/bin/mise" self-update --yes

  log "Updating mise tools..."

  "$HOME/.local/bin/mise" install
  "$HOME/.local/bin/mise" upgrade
}

# Schedules bin/sync-branches hourly: a systemd timer on exe.dev, where the
# journal keeps every run and a diverged branch shows as a failed unit, and cron
# everywhere else, since a macOS laptop has no systemd and crontab is the one
# scheduler it shares with Linux. Exactly one of the two may hold the job, or two
# runs fetch and fast-forward the same clones at once, so the exe.dev side also
# removes the cron block an earlier install wrote.
function do_sync_branches() {
  log "Scheduling branch sync..."

  if "$BASEDIR/bin/is-exe-dev"; then
    sync_branches_from_systemd
  else
    sync_branches_from_cron
  fi
}

function sync_branches_from_systemd() {
  local units=~/.config/systemd/user

  use_user_bus

  mkdir -p "$units"

  # Nothing in sync-branches bounds a fetch, and a oneshot has no start timeout
  # of its own, so a hung fetch would hold the unit activating and the timer
  # would skip every hour after it. The bound stays under the hour for that
  # reason.
  cat > "$units/sync-branches.service" << EOF
[Unit]
Description=Fast-forward every local branch to its upstream

[Service]
Type=oneshot
ExecStart=$BASEDIR/bin/sync-branches
TimeoutStartSec=30min
EOF

  cat > "$units/sync-branches.timer" << EOF
[Unit]
Description=Keep local branches current hourly

[Timer]
OnCalendar=*-*-* *:17:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

  systemctl --user daemon-reload
  systemctl --user enable --now sync-branches.timer

  exists crontab || return 0

  local current desired
  current="$(crontab -l 2>/dev/null || true)"
  desired="$(printf '%s\n' "$current" | without_cron_block sync-branches)"
  [[ $desired == "$current" ]] && return 0

  if [[ -n $desired ]]; then
    printf '%s\n' "$desired" | crontab -
  else
    crontab -r
  fi
}

# This owns a marked block in the user's crontab, the way `git maintenance start
# --scheduler=crontab` does, and replaces only that, so entries anyone else put
# there are left alone.
function sync_branches_from_cron() {
  exists crontab || return 0

  local begin="# BEGIN dotfiles sync-branches"
  local end="# END dotfiles sync-branches"
  local state=~/.local/state
  mkdir -p "$state"

  # Cron's PATH is /usr/bin:/bin, which on a Mac reaches Apple's git rather
  # than Homebrew's, so name the directory of the git this install resolved.
  local line="17 * * * * PATH=$(dirname "$(command -v git)"):/usr/bin:/bin \"$BASEDIR/bin/sync-branches\" > \"$state/sync-branches.log\" 2>&1"

  local current desired
  current="$(crontab -l 2>/dev/null || true)"
  desired="$(
    if [[ -n $current ]]; then
      printf '%s\n' "$current" | without_cron_block sync-branches
    fi
    printf '%s\n%s\n%s\n' "$begin" "$line" "$end"
  )"

  if [[ $desired == "$current" ]]; then
    echo "Already scheduled"
    return 0
  fi

  printf '%s\n' "$desired" | crontab -
}

# Filters stdin, a crontab, down to everything but the named dotfiles block.
function without_cron_block() {
  awk -v b="# BEGIN dotfiles $1" -v e="# END dotfiles $1" '$0 == b { skip = 1 } !skip { print } $0 == e { skip = 0 }'
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

# Schedules bin/tidy weekly. Gated on exe.dev rather than on a dev box, since a
# bot box fills its disk just the same, and nowhere else: a laptop's owner runs
# it through `update`.
function do_tidy() {
  local units=~/.config/systemd/user

  "$BASEDIR/bin/is-exe-dev" || return 0

  use_user_bus

  log "Scheduling tidy..."

  mkdir -p "$units"

  # Every step in tidy is skipped when its tool isn't on PATH, and a unit gets
  # only the system set, which would run the prunes that matter least and
  # quietly drop the ones that matter most. The mise shims need `mise` itself
  # beside them, and are safe only from a directory whose mise config is
  # trusted, so the working directory is pinned to %h rather than left implicit.
  cat > "$units/tidy.service" << EOF
[Unit]
Description=Reclaim disk from caches and stale builds the installed tools can get back

[Service]
Type=oneshot
WorkingDirectory=%h
Environment=PATH=$BASEDIR/bin:%h/.local/share/mise/shims:%h/.local/bin:%h/.cargo/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=$BASEDIR/bin/tidy
Nice=19
IOSchedulingClass=idle
EOF

  # Persistent catches up a week the box was off for. No run now: install.sh is
  # usually reached through `update`, which runs tidy itself right after.
  cat > "$units/tidy.timer" << EOF
[Unit]
Description=Reclaim disk weekly

[Timer]
OnCalendar=weekly
Persistent=true
RandomizedDelaySec=1h

[Install]
WantedBy=timers.target
EOF

  systemctl --user daemon-reload
  systemctl --user enable --now tidy.timer
}

# Ages out Claude Code's per-user scratch under /tmp. The exe.dev image keeps
# /tmp across reboots and cleans it only of entries 30 days old by every
# timestamp, so anything that lists a directory (a `du`, a file watcher) resets
# its clock and the scratchpads pile up for as long as the VM stays up. This is
# only a rule for the daily systemd-tmpfiles-clean.service the system already
# runs, so there is no unit or timer to install.
function do_scratchpad_cleanup() {
  "$BASEDIR/bin/is-exe-dev" || return 0

  log "Aging out Claude scratchpads..."

  # Written rather than symlinked out of this repo: root reads it, and a rule
  # that anything able to write the clone could change is a rule that can
  # delete any path on the machine. The glob is `claude-<uid>`, not `claude-*`,
  # which also matches files other tools keep in /tmp. `e` cleans inside each
  # match without creating or re-owning it. `cmM:` ages by modification and
  # status change alone, leaving out the access times a read or a listing
  # refreshes, so a file goes a week after it was last written whoever has
  # looked at it since.
  sudo tee /etc/tmpfiles.d/claude-scratchpads.conf > /dev/null << 'EOF'
e /tmp/claude-[0-9]* - - - cmM:7d
EOF
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

# Schedules bin/converge-atlas, which does the work of serving the box's front
# door on 8000, the port the bare `https://<vm>.exe.xyz/` hostname is proxied to,
# and is where the dev-box guard lives. The atlas writes its own unit, so this
# owns only the timer that keeps it on the current release, plus one run so the
# box is serving now rather than whenever the timer first comes round.
function do_atlas() {
  local units=~/.config/systemd/user

  "$BASEDIR/bin/is-dev-box" || return 0

  use_user_bus

  log "Serving the atlas..."

  mkdir -p "$units"

  cat > "$units/converge-atlas.service" << EOF
[Unit]
Description=Update exe-dev-atlas and converge this VM's index

[Service]
Type=oneshot
ExecStart=$BASEDIR/bin/converge-atlas
EOF

  # Daily with a randomised delay, for the same reasons as the codex: a box that
  # was shut down through its window still catches up, and every box does not
  # reach for the same release at the same instant.
  cat > "$units/converge-atlas.timer" << EOF
[Unit]
Description=Keep the atlas on the latest published exe-dev-atlas

[Timer]
OnCalendar=daily
Persistent=true
RandomizedDelaySec=1h

[Install]
WantedBy=timers.target
EOF

  systemctl --user daemon-reload
  systemctl --user enable --now converge-atlas.timer

  "$BASEDIR/bin/converge-atlas"
}

# Schedules bin/converge-mainplate, which does the work of serving a durable
# coding agent on 3002 and is where the dev-box guard lives. mainplate writes its
# own unit, so this owns only the timer that keeps it on the current tip of its
# default branch, plus one run so the box is serving now rather than whenever the
# timer first comes round.
#
# Every five minutes rather than daily, because this is the one of the three that
# is under active development: a commit lands and the box is serving it within the
# five minutes, not the next morning. What makes that affordable is that
# `converge-mainplate` asks what `main` points at before doing anything, so a tick
# with no new commit is one `git ls-remote` and no restart.
function do_mainplate() {
  local units=~/.config/systemd/user

  "$BASEDIR/bin/is-dev-box" || return 0

  use_user_bus

  log "Serving mainplate..."

  mkdir -p "$units"

  cat > "$units/converge-mainplate.service" << EOF
[Unit]
Description=Update mainplate and converge this VM's console

[Service]
Type=oneshot
ExecStart=$BASEDIR/bin/converge-mainplate
EOF

  # No `Persistent=true` and only seconds of randomisation, both of which the
  # codex and the atlas want and this does not. Catching up a missed window is
  # meaningless when the next window is five minutes out, and an hour of jitter
  # spread over a five-minute period would reorder the firings rather than spread
  # them. Thirty seconds is enough that a fleet of boxes does not ask GitHub the
  # same question on the same second.
  cat > "$units/converge-mainplate.timer" << EOF
[Unit]
Description=Keep mainplate on the current tip of its default branch

[Timer]
OnCalendar=*:0/5
RandomizedDelaySec=30

[Install]
WantedBy=timers.target
EOF

  systemctl --user daemon-reload
  systemctl --user enable --now converge-mainplate.timer

  "$BASEDIR/bin/converge-mainplate"
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

  restart_stale_zellij_session
}

# True when this script runs somewhere under process $1, as it does from a
# terminal in a zellij or herdr pane. Restarting that server would kill the
# install partway through along with the terminal it reports to.
function is_descendant_of() {
  local ancestor="$1"
  local pid=$$

  while ((pid > 1)); do
    ((pid == ancestor)) && return 0
    pid="$(awk '$1 == "PPid:" {print $2}' "/proc/$pid/status")"
  done
  return 1
}

# Moves the work session onto the zellij mise has installed when the server
# holding it still runs an older one, which otherwise lasts until a reboot. This
# ends every pane in the session, and zellij has no way to tell whether an agent
# in one is mid-turn, so the only thing guarding it is that the trigger is a
# person running install.sh.
#
# Stopped with `kill-session` rather than a signal: SIGTERM leaves the socket
# file behind. It works across releases because the socket directory is keyed
# by zellij's protocol contract rather than its version, so a protocol bump is
# where this stops working, and it fails loudly there rather than starting a
# second session beside the first.
function restart_stale_zellij_session() {
  local zellij=~/.local/share/mise/shims/zellij
  local session pid running installed

  session="$(hostname -s)"
  pid="$(pgrep -u "$(id -u)" -f "^[^ ]*zellij --server $ZELLIJ_SOCKET_DIR/contract_version_[0-9]+/$session\$")"
  [[ -n "$pid" ]] || return 0

  # The old binary is usually gone by now, so compare paths rather than asking
  # it for a version.
  running="$(readlink "/proc/$pid/exe")"
  running="${running% (deleted)}"
  installed="$(realpath "$("$HOME/.local/bin/mise" which zellij)")"
  [[ "$running" != "$installed" ]] || return 0

  if is_descendant_of "$pid"; then
    log "Not restarting the zellij session from inside it; detach, then: zellij kill-session $session && systemctl --user restart zellij-session"
    return 0
  fi

  log "Restarting the zellij work session on the upgraded zellij..."

  if ! "$zellij" kill-session "$session"; then
    log "zellij could not stop session $session; see 'ps -p $pid'"
    return 1
  fi

  # The unit's `attach --create-background` treats an existing session as
  # success, so restarting it before the old server is gone recreates nothing.
  local tries=0
  while kill -0 "$pid" 2> /dev/null; do
    if ((++tries > 50)); then
      log "zellij session $session did not exit; see 'ps -p $pid'"
      return 1
    fi
    sleep 0.1
  done

  systemctl --user restart zellij-session.service
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

  # A daemon this repo starts directly, rather than a released tool that installs
  # its own unit, so there is no timer here: the unit is the whole of it.
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

  # Unconditionally, rather than `enable --now`: the file above may have changed
  # under a running server, and there is no work in flight to preserve.
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

# Keeps a herdr server up from boot, the herdr counterpart of the zellij work
# session: its panes and agents exist because the box is up, not because
# somebody connected. `herdr` from a login attaches to it, since both find it at
# ~/.config/herdr/herdr.sock, which herdr derives from the home directory rather
# than XDG_RUNTIME_DIR, so there is no socket directory to pin the way zellij
# needs one.
#
# Unlike the zellij session, the panes live inside this unit: `herdr server`
# stays in the foreground and its children share the unit's cgroup, so `stop`
# and `restart` end every pane and agent in it. Restarting is therefore left to
# restart_stale_herdr_server, which does it only for an upgrade.
#
# PATH is what the server hands to every pane and plugin command, so it carries
# the mise shims for the plugin's bun and node as well as for herdr itself.
function do_herdr_server() {
  local units=~/.config/systemd/user

  "$BASEDIR/bin/is-dev-box" || return 0

  use_user_bus

  log "Converging the herdr server..."

  mkdir -p "$units"

  cat > "$units/herdr-server.service" << 'EOF'
[Unit]
Description=Keep this box's herdr server running

[Service]
ExecStart=%h/.local/share/mise/shims/herdr server
Environment=PATH=%h/.local/share/mise/shims:%h/.local/bin:/usr/local/bin:/usr/bin:/bin
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF

  systemctl --user daemon-reload
  systemctl --user enable --now herdr-server.service

  restart_stale_herdr_server
}

# Moves the herdr server onto the herdr mise has installed when it still runs an
# older one. Panes come back as fresh shells in their saved directories and the
# layout returns, but the processes in them end, so this waits for a run in
# which no agent is mid-turn or waiting on an answer. herdr's own live handoff
# would keep the processes, but it belongs to herdr's updater, which a mise
# install cannot use.
function restart_stale_herdr_server() {
  local herdr=~/.local/share/mise/shims/herdr
  local running installed pid

  # Empty while a freshly enabled server is still starting, which needs nothing.
  running="$("$herdr" status server | awk '$1 == "version:" {print $2}')"
  installed="$("$herdr" --version | awk '{print $2}')"
  [[ -n "$running" && "$running" != "$installed" ]] || return 0

  pid="$(systemctl --user show -p MainPID --value herdr-server.service)"
  if is_descendant_of "$pid"; then
    log "Not restarting herdr $running from inside it; detach, then: systemctl --user restart herdr-server"
    return 0
  fi

  if "$herdr" agent list | jq -e 'any(.. | objects | .agent_status?; . == "working" or . == "blocked")' > /dev/null; then
    log "Not restarting herdr $running while an agent is working or waiting; rerun install.sh later"
    return 0
  fi

  log "Restarting the herdr server on herdr $installed..."
  systemctl --user restart herdr-server.service
}

# Serves herdr web ui (https://github.com/devswha/herdr-web-ui), a browser and
# phone client for the herdr server above, at `https://<vm>.exe.xyz:3003/`.
#
# It is a herdr plugin rather than a unit of its own: its startup hook brings the
# web server up each time the herdr server starts, inside that server's cgroup.
# The plugin reads its settings from an env file in its herdr config directory,
# not from any environment of ours, and only at start, so a changed file means
# restarting the plugin, which leaves herdr and its agents alone.
#
# The server binds loopback by default and the exe.dev proxy reaches it there.
# The proxy sends X-Forwarded-For, which is what makes the app count a visitor
# as remote rather than as this computer: remote visitors are let in only until
# the first device pairs (Settings, Phone & devices), and need a pairing code of
# their own after that. Pair a browser right after first install so the private
# exe.dev proxy is not the only gate. Like VS Code's port, this one hands out
# terminals: never `share set-public` it.
#
# Installed once, at the latest release tag, then left to the app's own updater
# (Settings, About), which replaces the checkout herdr manages. Reinstalling on
# every converge would undo each of those updates.
function do_herdr_web() {
  local plugin=devswha.herdr-web-ui
  local repo=devswha/herdr-web-ui
  local herdr=~/.local/share/mise/shims/herdr

  "$BASEDIR/bin/is-dev-box" || return 0

  log "Converging herdr web ui..."

  # `enable --now` returns before the server is listening, and every plugin
  # command below talks to it. `herdr status server` exits 0 whether or not it
  # is up, so the socket appearing is the signal to wait on.
  local tries=0
  until [[ -S ~/.config/herdr/herdr.sock ]]; do
    if ((++tries > 50)); then
      log "herdr server did not come up; see systemctl --user status herdr-server"
      return 1
    fi
    sleep 0.1
  done

  local env_file
  env_file="$("$herdr" plugin config-dir "$plugin")/env"
  local wanted
  wanted="$(printf 'PORT=3003\nHERDR_WEB_TELEMETRY=0\nHERDR_WEB_APP_NAME=%s\n' "$(hostname -s)")"
  local is_env_changed=false
  if [[ "$(cat "$env_file" 2> /dev/null)" != "$wanted" ]]; then
    printf '%s\n' "$wanted" > "$env_file"
    is_env_changed=true
  fi

  # Matching the id anywhere in the listing rather than at a field path, which
  # herdr does not document.
  if ! "$herdr" plugin list --json | jq -e --arg id "$plugin" 'any(.. | strings; . == $id)' > /dev/null; then
    local tag
    tag="$(git ls-remote --tags --refs --sort=-v:refname "https://github.com/$repo" 'v*' | head -1 | sed 's|.*refs/tags/||')"
    # The build runs bun and node from this process's PATH, not the server's.
    PATH=~/.local/share/mise/shims:$PATH "$herdr" plugin install "$repo" --ref "$tag" --yes
    "$herdr" plugin action invoke "$plugin.start" > /dev/null
  elif [[ "$is_env_changed" == true ]]; then
    "$herdr" plugin action invoke "$plugin.stop" > /dev/null
    "$herdr" plugin action invoke "$plugin.start" > /dev/null
  fi
}

do_config

. "$HOME/.commonrc-pre"

do_ssh_key
do_apt
do_locale
do_perf_sysctl
do_brew
do_mise
do_sync_branches
do_tidy
do_scratchpad_cleanup
do_cloister
do_atlas
do_mainplate
do_zellij_session
do_zellij_web
do_vscode_web
do_herdr_server
do_herdr_web
