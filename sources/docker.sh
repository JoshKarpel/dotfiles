#!/usr/bin/env bash

alias dip="docker image prune -f"
alias dcp="docker container prune -f"

function docker_build_context() {
  ncdu -X "$(git_root)"/.dockerignore
}
