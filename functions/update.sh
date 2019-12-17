#!/usr/bin/env bash

function update() {
  git --git-dir="$(realpath ~/dotfiles/.git)" pull
  bash ~/dotfiles/install.sh
  source ~/.bashrc
}
