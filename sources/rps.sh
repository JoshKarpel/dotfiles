#!/usr/bin/env bash

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
