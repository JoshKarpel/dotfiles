#!/usr/bin/env bash

function update() {
  (cd ~/dotfiles/ || exit 1 && git pull && ~/.python/bin/python -m pre_commit run --all && bash ~/dotfiles/install.sh)
  reload
}

function reload() {
  case $(shell) in
    "bash") source ~/.bashrc ;;
    "zsh") source ~/.zshrc ;;
  esac
}
