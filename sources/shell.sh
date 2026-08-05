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

# For integrations that only draw a prompt or complete a word, both of which
# need someone at a keyboard. bash sources the rc chain for `ssh <host>
# <command>` runs as well, so anything that costs a process start there is paid
# for nothing. Tool setup that changes PATH is _not_ this: a non-interactive
# command needs it just as much.
function activate_if_interactive() {
  if [[ $- != *i* ]]; then
    return 0
  fi

  activate_if_available "$@"
}

# Ctrl+d on an empty prompt exits the shell, which in the last pane of a
# multiplexer takes the whole session with it. Requiring `exit` costs one word
# and removes a keystroke's worth of blast radius. Interactive only: a script
# reading stdin still needs EOF to mean EOF.
if [[ $- == *i* ]]; then
  set -o ignoreeof
fi
