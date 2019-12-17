#!/usr/bin/env bash

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

MINICONDA_INSTALLER_PATH=~/miniconda-installer.sh
# install miniconda
function install_miniconda() {
  bar
  curl https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -fsSL -o $MINICONDA_INSTALLER_PATH
  bash ~/miniconda-installer.sh -b -p ~/.python
  bar
}

if exists conda; then
  echo "  conda already installed"
else
  echo "  installing miniconda"
  install_miniconda
fi

# cleanup from miniconda install
[[ -f $MINICONDA_INSTALLER_PATH ]] && rm $MINICONDA_INSTALLER_PATH

source ~/.bashrc

function update_conda() {
  bar
  conda update -n base --all -y
  conda clean --all -y
  bar
}

echo "    updating base conda and cleaning"
update_conda

function install_rbenv() {
  bar
  curl https://github.com/rbenv/rbenv-installer/raw/master/bin/rbenv-installer -fsSL | bash
  bar
}

if exists rbenv; then
  echo "  rbenv already installed"
else
  echo "  installing rbenv"
  install_rbenv
fi

source ~/.bashrc

function update_ruby() {
  bar
  version="$(rbenv install -l | grep -v - | tail -1)"
  rbenv install "$version"
  rbenv global "$version"
  bar
}

echo "    updating default ruby version"
update_ruby

# install rust
function install_rust() {
  bar
  curl https://sh.rustup.rs -fsSL | bash -s -- -y --no-modify-path
  bar
}

if exists rustup; then
  echo "  rust already installed"
else
  echo "  installing rust"
  install_rust
fi

source ~/.bashrc

echo "  installing cargo packages"
function install_cargo_packages() {
  bar
  cargo install $(cat "$BASEDIR/cargo_install_targets.txt" | xargs)
  cargo install-update --all
  bar
}

install_cargo_packages

source ~/.bashrc
