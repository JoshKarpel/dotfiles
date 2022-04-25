#!/usr/bin/env bash

export PATH="$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH"

function path_prefix() {
  [[ -n $1 ]] || {
    echo "ERROR: missing argument for path_prefix"
    return 1
  }

  export PATH="$(realpath "$1")":$PATH
}

function path_postfix() {
  [[ -n $1 ]] || {
    echo "ERROR: missing argument for path_postfix"
    return 1
  }

  export PATH=$PATH:"$(realpath "$1")"
}

function path_dedup() {
  export PATH=$(dedup-path)
}

function path_display() {
  IFS=':' read -r -a paths <<<"$PATH"
  for index in "${!paths[@]}"; do
    echo "$index!${paths[index]}"
  done | tac | column -t -s "!"
}
