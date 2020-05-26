#!/usr/bin/env bash

alias py="python"
alias ipy="ipython"
alias pc="python -c"
alias ipc="ipython -i -c"
alias pm="python -m"

function clean_python_cache() {
  find . -type f -name "*.py[co]" -print -delete
  find . -type d -name "__pycache__" -print -delete
}
