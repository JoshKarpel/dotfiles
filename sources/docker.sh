#!/usr/bin/env bash

alias dip="docker image prune -f"
alias dcp="docker container prune -f"

function hadolint() {
  docker run \
    --rm -i \
    -v "$(pwd)"/.hadolint.yaml:/bin/hadolint.yaml \
    -e XDG_CONFIG_HOME=/bin \
    hadolint/hadolint
}
