#!/usr/bin/env bash

alias p="python"

function clean_python_cache() {
  find . -type f -name "*.py[co]" -print -delete
  find . -type d -name "__pycache__" -print -delete
}
