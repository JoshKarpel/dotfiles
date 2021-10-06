#!/usr/bin/env bash

function update() {
  (cd ~/dotfiles/ || exit 1 && git pull && pre-commit run --all)
  sudo bash ~/dotfiles/install.sh
  reload
}

function reload() {
  case $(shell) in
    "bash") source ~/.bashrc ;;
    "zsh") source ~/.zshrc ;;
  esac
}
