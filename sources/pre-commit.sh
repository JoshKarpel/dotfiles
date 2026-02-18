#!/usr/bin/env bash

function _pre_commit() {
  if is_uv_project; then
    uv run pre-commit "$@"
  else
    uvx pre-commit "$@"
  fi
}

alias pci="_pre_commit install"
alias pcaa="_pre_commit autoupdate"

function pcr() {
  local rc
  git add --update
  _pre_commit run --show-diff-on-failure "$@"
  rc=$?
  if [[ $rc -ne 0 ]]; then
    git add --update
  fi
  return $rc
}

function pcinit() {
  _pre_commit sample-config > .pre-commit-config.yaml
  _pre_commit autoupdate
}
