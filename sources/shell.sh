#!/usr/bin/env bash

function shell() {
  # Ask the shell to identify itself rather than reading the process table:
  # `ps -o comm` disagrees across GNU and BSD about whether it prints a bare
  # name or a full path, and callers match these strings exactly, so a full
  # path makes every branch fall through in silence.
  if [[ -n ${ZSH_VERSION:-} ]]; then
    echo zsh
  elif [[ -n ${BASH_VERSION:-} ]]; then
    echo bash
  else
    return 1
  fi
}

function activate_if_available() {
  local cmd="$1"
  if exists "$cmd"; then
    shift
    eval "$("$@")"
  else
    echo "WARNING: $cmd not found; skipping shell integration" >&2
  fi
}
