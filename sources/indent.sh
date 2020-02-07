#!/usr/bin/env bash

function indent() {
  while read -r line; do
    printf "%*s%s\n" "$1" '' "$line"
  done <"${2:-/dev/stdin}"
}
