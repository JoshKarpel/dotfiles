#!/usr/bin/env bash

function title() {
  export TITLE_SET_MANUALLY=true
  _set_title "$@"
}

function unset_title() {
  export TITLE_SET_MANUALLY=false
}

function _set_title() {
  printf "\033]0;%s\007" "$1"
}
