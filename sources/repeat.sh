#!/usr/bin/env bash

function repeat() {
  local number="$1"
  shift

  for _ in $(seq "$number"); do
    $@
  done
}
