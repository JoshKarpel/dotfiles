#!/usr/bin/env bash

alias py="python"
alias ipy="ipython"

function clean_python_cache() {
  find . -type f -name "*.py[co]" -print -delete
  find . -type d -name "__pycache__" -print -delete
}
