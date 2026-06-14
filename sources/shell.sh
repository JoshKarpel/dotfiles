#!/usr/bin/env bash

function shell() {
  ps -p $$ -o comm -h | tail -n 1 | sed 's/-//'
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
