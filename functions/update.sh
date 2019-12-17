#!/usr/bin/env bash

function update_dotfiles {
    git --git-dir="$(realpath ~/dotfiles/.git)" pull
    bash ~/dotfiles/install.sh
    source "$(realpath ~/.bashrc)"
}
