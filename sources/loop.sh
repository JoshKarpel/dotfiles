#!/usr/bin/env bash

function loop() {
  local delay="$1"
  shift

  while true; do
    $@
    sleep "$delay"
  done
}

function loop_until_success() {
  while true; do
    if $@; then
      return 0
    fi
  done
}

function loop_until_failure() {
  while true; do
    if ! $@; then
      return 0
    fi
  done
}
