#!/usr/bin/env bash

alias dr="docker run -it --rm"
alias db="docker build"
alias dip="docker image prune -f"
alias dcp="docker container prune -f"

function docker_build_context() {
  ncdu -X "$(git_root)"/.dockerignore
}
