#!/usr/bin/env bash

set -eu
set -o pipefail

function exists_and_not_symlink() {
  [[ (-f $1) && (! -L $1) ]]
}

BASEDIR="$(dirname "$(realpath -s "$0")")"

echo dotfile directory is $BASEDIR

BACKUPS=~/dotfiles-backup
mkdir -p $BACKUPS

# make symlinks in the home dir for each files in dotrc
echo "  creating symlinks in home dir for files in dotrc"
DOTRC=$BASEDIR/dotrc
echo "    dotrc directory is $DOTRC"
for file in $DOTRC/*; do
  [[ -f $file ]] || continue

  target=~/."$(basename "$file")"

  if exists_and_not_symlink $target; then
    backup=$BACKUPS/"$(basename "$target")"
    echo "    moving existing file $target to $backup"
    mv $target $backup
  fi

  echo "    making symlink: $target -> $file"
  ln -sf $file "$target"
done

source ~/.bashrc

# install miniconda
function install_miniconda() {
  bar
  curl https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -sSf -o ~/miniconda-installer.sh
  bash ~/miniconda-installer.sh -b -p ~/.python
  rm ~/miniconda-installer.sh
  bar
}

if exists conda; then
  echo "  conda already installed"
else
  echo "  installing miniconda"
  install_miniconda
fi

# install rust
function install_rust() {
  bar
  curl https://sh.rustup.rs -sSf | bash -s -- -y --no-modify-path
  bar
}

if exists rustup; then
  echo "  rust already installed"
else
  echo "  installing rust"
  install_rust
fi

source ~/.bashrc
