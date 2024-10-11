#!/usr/bin/env bash

alias pci="pre-commit install"
alias pcaa="pre-commit autoupdate"

function pcr() {
  git add --update
  uvx pre-commit run $@
  git add --update
}

function pca() {
  git add --update
  uvx pre-commit run -a $@
  git add --update
}

function pcinit() {
  uvx pre-commit sample-config > .pre-commit-config.yaml
  uvx pre-commit autoupdate
}
