#!/usr/bin/env bash

function update() {
  (cd ~/dotfiles/ || exit 1; git pull)
  bash ~/dotfiles/install.sh
  source ~/.bashrc
}
