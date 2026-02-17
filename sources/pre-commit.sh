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
  git add --update
  _pre_commit run "$@"
  git add --update
}

function pca() {
  git add --update
  _pre_commit run -a "$@"
  git add --update
}

function pcinit() {
  _pre_commit sample-config > .pre-commit-config.yaml
  _pre_commit autoupdate
}
