#!/usr/bin/env bash

function path_prefix() {
  [[ -n $1 ]] || {
    echo "ERROR: missing argument for path_prefix"
    return 1
  }

  path_remove "$1"
  export PATH="$(realpath "$1")":$PATH
}

function path_postfix() {
  [[ -n $1 ]] || {
    echo "ERROR: missing argument for path_postfix"
    return 1
  }

  path_remove "$1"
  export PATH=$PATH:"$(realpath "$1")"
}

function path_remove() {
  [[ -n $1 ]] || {
    echo "ERROR: missing argument for path_remove"
    return 1
  }

  local component path
  component=":$1:"
  path=":$PATH:"
  path=${path//$component/:}
  path=${path/#:/}
  export PATH=${path/%:/}
}

function path_display() {
  IFS=':' read -r -a paths <<<"$PATH"
  for index in "${!paths[@]}"; do
    echo "$index!${paths[index]}"
  done | tac | column -t -s "!"
}
