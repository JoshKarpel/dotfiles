#!/usr/bin/env bash

function mk() {
  [[ -n $1 ]] || {
    echo "ERROR: missing argument to mk"
    return 1
  }

  mkdir -v -p "$1" && cd "$1" || return 1
}
