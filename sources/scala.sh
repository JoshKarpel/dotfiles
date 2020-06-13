#!/usr/bin/env bash

function mill() {
  target="$(git_root)"/mill
  if [[ ! -f $target ]]; then
    echo "Mill not installed in this repository; downloading..."
    curl -L https://github.com/lihaoyi/mill/releases/download/0.7.3/0.7.3 -o mill
    chmod +x mill
  fi
  $target
}
