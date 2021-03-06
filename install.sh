#!/usr/bin/env bash

function exists_and_not_symlink() {
  [[ (-e $1) && (! -L $1) ]]
}

function install_conda() {
  bar
  curl https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-x86_64.sh -fsSL -o $MINICONDA_INSTALLER_PATH
  bash ~/miniconda-installer.sh -b -p ~/.python
  bar
}

function update_conda() {
  bar
  conda install -y -n base $(cat "$BASEDIR/targets/conda.txt" | xargs)
  conda update -y --all -n base
  conda clean -y --all
  conda run -n base python -m pip install --no-cache-dir --upgrade $(cat "$BASEDIR/targets/pip.txt" | xargs)
  bar
}

function install_poetry() {
  bar
  curl -sSL https://raw.githubusercontent.com/python-poetry/poetry/master/get-poetry.py | python -
  bar
}

function update_poetry() {
  bar
  poetry self update
  bar
}

function install_rbenv() {
  bar
  curl https://github.com/rbenv/rbenv-installer/raw/master/bin/rbenv-installer -fsSL | bash
  bar
}

function update_ruby() {
  bar
  gem update --system
  gem cleanup
  bar
}

function install_rust() {
  bar
  curl https://sh.rustup.rs -fsSL | bash -s -- -y --no-modify-path
  bar
}

function update_rust() {
  bar
  rustup default stable
  rustup update
  bar
}

function install_cargo_packages() {
  bar
  cargo install $(cat "$BASEDIR/targets/cargo.txt" | xargs)
  bar
}

function install_zsh() {
  bar
  sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  bar
}

echo "executing install script"

BASEDIR="$(dirname "$(realpath -s "$0")")"

echo "dotfile directory is $BASEDIR"

BACKUPS=~/.dotfiles-backups

echo "creating symlinks in home dir for files in dotrc"
DOTRC=$BASEDIR/dotrc
for file in "$DOTRC"/*; do
  [[ -f $file ]] || continue

  target=~/."$(basename "$file")"

  if exists_and_not_symlink $target; then
    mkdir -p $BACKUPS
    backup=$BACKUPS/"$(basename "$target")"
    echo "moving existing file $target to $backup"
    mv $target $backup
  fi

  echo "$target -> $file"
  ln -sf "$file" "$target"
done

CONFIG=$BASEDIR/config
mkdir -p "$CONFIG"
mkdir -p ~/.config
for dir in "$CONFIG"/*; do
  target=~/.config/"$(basename "$dir")"
  echo "$target -> $dir"
  ln -nsf "$dir" "$target"
done

source ~/.commonrc

MINICONDA_INSTALLER_PATH=~/miniconda-installer.sh

if exists conda; then
  echo "conda already installed"
else
  echo "installing miniconda"
  install_conda
fi

# cleanup from miniconda install
[[ -f $MINICONDA_INSTALLER_PATH ]] && rm $MINICONDA_INSTALLER_PATH

source ~/.commonrc

echo "updating base conda and cleaning"
update_conda

if exists poetry; then
  echo "poetry already installed"
else
  echo "installing poetry"
  install_poetry
fi

source ~/.commonrc

echo "updating poetry"
update_poetry

if exists rbenv; then
  echo "updating rbenv"
  install_rbenv
else
  echo "installing rbenv"
  install_rbenv
fi

source ~/.commonrc

echo "updating default ruby version"
update_ruby

if exists rustup; then
  echo "rust already installed"
else
  echo "installing rust"
  install_rust
fi

echo "updating rust"
update_rust

source ~/.commonrc

echo "installing cargo packages"
install_cargo_packages

source ~/.commonrc

if [[ $(shell) == "zsh" && ! -d "$ZSH" ]]; then
  echo "installing Oh My Zsh"
  install_zsh
fi
