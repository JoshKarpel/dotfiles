#!/usr/bin/env bash

function update() {
  (
    cd "$DOTFILES" || {
      echo "ERROR: Could not cd to $DOTFILES" >&2
      return 1
    }
    echo "Pulling latest changes..."
    git pull || {
      echo "ERROR: git pull failed" >&2
      return 1
    }
    echo "Running install.sh..."
    bash "$DOTFILES/install.sh" || {
      echo "ERROR: install.sh failed" >&2
      return 1
    }
  )
  tidy
  reload
}

function reload() {
  case $(shell) in
    "bash") . ~/.bashrc ;;
    "zsh") . ~/.zshrc ;;
  esac
}
