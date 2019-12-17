#!/usr/bin/env bash

function update_dotfiles {
    git --git-dir=~/dotfiles/.git pull
    bash ~/dotfiles/install.sh
    source ~/.bashrc
}
