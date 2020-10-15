#!/usr/bin/env bash

alias pci="pre-commit install"
alias pcaa="pre-commit autoupdate"

function pcr() {
    git add --update
    pre-commit run
}

function pca() {
    git add --update
    pre-commit run -a
}