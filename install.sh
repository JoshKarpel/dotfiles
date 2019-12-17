#!/usr/bin/env bash

function exists_and_not_symlink() {
  [[ (-f $1) && (! -L $1) ]]
}

function install_conda() {
  bar
  curl https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -fsSL -o $MINICONDA_INSTALLER_PATH
  bash ~/miniconda-installer.sh -b -p ~/.python
  bar
}

function update_conda() {
  bar
  conda update -n base --all -y
  conda clean --all -y
  bar
}

function install_rbenv() {
  bar
  curl https://github.com/rbenv/rbenv-installer/raw/master/bin/rbenv-installer -fsSL | bash
  bar
}

function update_ruby() {
  bar
  version="$(rbenv install -l | grep -v - | tail -1)"
  rbenv install -s "$version"
  rbenv global "$version"
  bar
}

function install_rust() {
  bar
  curl https://sh.rustup.rs -fsSL | bash -s -- -y --no-modify-path
  bar
}

function update_rust() {
  bar
  rustup update
  bar
}

function install_cargo_packages() {
  bar
  cargo install $(cat "$BASEDIR/cargo_install_targets.txt" | xargs)
  cargo install-update --all
  bar
}

echo "executing install script"

BASEDIR="$(dirname "$(realpath -s "$0")")"

echo "dotfile directory is $BASEDIR"

BACKUPS=~/.dotfiles-backups

echo "  creating symlinks in home dir for files in dotrc"
DOTRC=$BASEDIR/dotrc
echo "    dotrc directory is $DOTRC"
for file in $DOTRC/*; do
  [[ -f $file ]] || continue

  target=~/."$(basename "$file")"

  if exists_and_not_symlink $target; then
    mkdir -p $BACKUPS
    backup=$BACKUPS/"$(basename "$target")"
    echo "    moving existing file $target to $backup"
    mv $target $backup
  fi

  echo "    making symlink: $target -> $file"
  ln -sf $file "$target"
done

source ~/.bashrc

MINICONDA_INSTALLER_PATH=~/miniconda-installer.sh

if exists conda; then
  echo "  conda already installed"
else
  echo "  installing miniconda"
  install_conda
fi

# cleanup from miniconda install
[[ -f $MINICONDA_INSTALLER_PATH ]] && rm $MINICONDA_INSTALLER_PATH

source ~/.bashrc

echo "    updating base conda and cleaning"
update_conda

if exists rbenv; then
  echo "  rbenv already installed"
else
  echo "  installing rbenv"
  install_rbenv
fi

source ~/.bashrc

echo "    updating default ruby version"
update_ruby

if exists rustup; then
  echo "  rust already installed"
else
  echo "  installing rust"
  install_rust
fi

echo "    updating rust"
update_rust

source ~/.bashrc

echo "  installing cargo packages"

install_cargo_packages

source ~/.bashrc
