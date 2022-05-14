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
}

function do_apt() {
  if ! exists apt-get; then
    return 0
  fi

  log "Updating apt targets..."

  sudo apt update -y
  xargs -r -a "$BASEDIR/targets/apt.txt" -- sudo apt install -y
  sudo apt upgrade -y
  sudo apt autoremove -y
}

function do_brew() {
  if ! [[ $(uname) == "Darwin" ]]; then
    return 0
  fi

  if ! exists brew; then
    log "Installing brew..."

    NONINTERACTIVE=1 sudo /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi

  log "Updating brew targets..."

  brew update

  brew install --display-times findutils  # BSD xargs doesn't have -a
  path_prefix "/usr/local/opt/findutils/libexec/gnubin"

  xargs -r -a "$BASEDIR/targets/brew.txt" -- brew install --display-times

  brew upgrade

  brew cleanup
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

  log "Updating conda..."

  conda update -y --all -n base

  log "Cleaning conda and pip caches..."

  conda clean -y --all
}

function do_pipx() {
  conda run -n base python -m pip install --upgrade pip pipx

  xargs -r -a "$BASEDIR/targets/pipx.txt" -n 1 -- conda run -n base python -m pipx install
  conda run -n base python -m pipx upgrade-all
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
  npm install --global npm@latest
  npm install --global yarn@latest
}

function do_rust() {
  if ! exists rustup; then
    log "Installing rust..."

    curl https://sh.rustup.rs -fsSL | bash -s -- -y --no-modify-path
    . $HOME/.cargo/env
  fi

  log "Updating rust..."

  rustup update

  log "Updating rust targets..."

  xargs -r -a "$BASEDIR/targets/cargo.txt" -- cargo install
}

do_config

. "$HOME/.commonrc"

do_apt
do_brew
do_conda
do_pipx
do_nvm
do_rust
