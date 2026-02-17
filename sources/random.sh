#!/usr/bin/env bash

function random() {
  local min=$1 max=$2
  echo $(( RANDOM % (max - min + 1) + min ))
}

function flip() {
  random 0 1
}

function d4() {
  random 1 4
}

function d6() {
  random 1 6
}

function d8() {
  random 1 8
}

function d10() {
  random 1 10
}

function d12() {
  random 1 12
}

function d20() {
  random 1 20
}

function rps() {
  case $(($RANDOM % 3)) in
    0)
      echo "rock"
      ;;
    1)
      echo "paper"
      ;;
    2)
      echo "scissors"
      ;;
  esac
}

function random_file() {
  if [[ -z "$1" ]]; then
    local dir=$(pwd)
  else
    local dir=$1
  fi

  realpath "$(find "$dir" -type f | shuf -n 1)"
}
