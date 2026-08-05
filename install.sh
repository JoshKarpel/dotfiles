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

  if [[ -f $key ]]; then
    echo "SSH key already exists at $key"
    return 0
  fi

  log "Generating SSH key..."

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
}

function do_locale() {
  log "Updating locale..."

  if ! exists locale-gen; then
    return 0
  fi

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

  brew cleanup

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
  "$HOME/.local/bin/mise" prune --yes
}

do_config

. "$HOME/.commonrc-pre"

do_ssh_key
do_apt
do_locale
do_brew
do_mise
