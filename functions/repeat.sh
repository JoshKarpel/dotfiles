#!/usr/bin/env bash

function repeat() {
  local delay="$1"
  shift

  while true; do
    $@
    sleep "$delay"
  done
}
