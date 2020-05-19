#!/usr/bin/env bash

function title() {
  export TITLE_SET_MANUALLY=true
  _set_title "$@"
}

function _set_title() {
  printf "\033]0;$*\007"
}
