#!/usr/bin/env bash

alias dr="docker run -it --rm"
alias db="docker build"
alias dip="docker image prune -f"
alias dcp="docker container prune -f"

function hadolint() {
  docker run \
    --rm -i \
    -v "$(git_root)"/.hadolint.yaml:/bin/hadolint.yaml \
    -e XDG_CONFIG_HOME=/bin \
    hadolint/hadolint
}

function docker_build_context() {
  ncdu -X "$(git_root)"/.dockerignore
}
