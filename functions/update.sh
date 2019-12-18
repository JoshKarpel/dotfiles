#!/usr/bin/env bash

function update() {
  git -C="$(realpath ~/dotfiles/.git)" pull
  bash ~/dotfiles/install.sh
  source ~/.bashrc
}
