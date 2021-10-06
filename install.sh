#!/usr/bin/env bash

BASEDIR="$(dirname "$(realpath -s "$0")")"

function exists_and_not_symlink() {
  [[ (-e $1) && (! -L $1) ]]
}

function log() {
  printf "\n\033[0;30;46m$1\033[0m\n"
}

function do_config() {
  BACKUPS=~/.dotfiles-backups

  log "Creating symlinks in $HOME for files in dotrc..."

  DOTRC=$BASEDIR/dotrc
  for file in "$DOTRC"/*; do
    [[ -f $file ]] || continue

    target=~/."$(basename "$file")"

    if exists_and_not_symlink "$target"; then
      mkdir -p $BACKUPS
      backup=$BACKUPS/"$(basename "$target")"
      echo "  mv $target -> $backup"
      mv $target $backup
    fi

    echo "  ln -s $target -> $file"
    ln -sf "$file" "$target"
  done

  touch ~/.gitconfig-local

  CONFIG=$BASEDIR/config
  mkdir -p "$CONFIG"
  mkdir -p ~/.config
  for dir in "$CONFIG"/*; do
    target=~/.config/"$(basename "$dir")"
    echo "  ln -s $target -> $dir"
    ln -nsf "$dir" "$target"
  done
}

function do_apt() {
  if ! exists apt; then
    return 0
  fi

  log "Updating apt packages..."

  apt update -y
  xargs -r -a "$BASEDIR/targets/apt.txt" -- apt install -y
  apt upgrade -y
  apt autoremove -y
}

function do_brew() {
  if [[ $(uname) -eq "Darwin" ]]; then
    return 0
  fi

  if ! exists brew; then
    curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | bash
  fi

  brew update
  xargs -r -a "BASEDIR/targets/brew.txt" -- brew install
  brew upgrade
}

function do_conda() {
  if ! exists conda; then
    log "Installing conda..."

    case $(uname) in
      Darwin)
        URL=https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-x86_64.sh
        ;;
      *)
        URL=https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
        ;;
    esac

    MINICONDA_INSTALLER_PATH=$(mktemp)
    curl $URL -fsSL -o "$MINICONDA_INSTALLER_PATH"
    bash "$MINICONDA_INSTALLER_PATH" -b -p ~/.python
    rm -f "$MINICONDA_INSTALLER_PATH"
  fi

  log "Updating conda and conda targets..."

  xargs -r -a "$BASEDIR/targets/conda.txt" -- conda install -y -n base
  conda update -y --all -n base

  log "Updating pip targets..."

  xargs -r -a "$BASEDIR/targets/pip.txt" -- conda run -n base python -m pip install --no-cache-dir --upgrade

  log "Cleaning conda and pip caches..."
  conda clean -y --all
}

function do_poetry() {
  if ! exists poetry; then
    log "Installing poetry..."

    curl -sSL https://raw.githubusercontent.com/python-poetry/poetry/master/get-poetry.py | python -
  fi

  log "Updating poetry..."

  poetry self update
}

function do_nvm() {
  NVM_DIR="$HOME/.nvm"

  if ! exists nvm; then
    log "Installing nvm..."
    git clone https://github.com/nvm-sh/nvm.git "$NVM_DIR"
  fi

  log "Updating nvm..."

  cd "$NVM_DIR" || return 1
  git fetch --tags origin
  git checkout "$(git describe --abbrev=0 --tags --match "v[0-9]*" "$(git rev-list --tags --max-count=1)")"

  nvm install --lts
  npm install --global yarn
}

function do_rust() {
  if ! exists rustup; then
    log "Installing rust..."

    curl https://sh.rustup.rs -fsSL | bash -s -- -y --no-modify-path
  fi

  log "Updating rust..."

  rustup update

  log "Updating rust targets..."

  xargs -r -a "$BASEDIR/targets/cargo.txt" -- cargo install
}

do_config

source ~/.commonrc

do_apt
do_brew
do_conda
do_poetry
do_nvm
do_rust
