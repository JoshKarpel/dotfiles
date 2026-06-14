#!/usr/bin/env bash

alias pci="pre-commit-run install"
alias pcaa="pre-commit-run autoupdate"
alias pcr="pre-commit-autofix --show-diff-on-failure"
alias pca="pre-commit-autofix --show-diff-on-failure --all-files"

function pcinit() {
  pre-commit-run sample-config > .pre-commit-config.yaml
  pre-commit-run autoupdate
}
