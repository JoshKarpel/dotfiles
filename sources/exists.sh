#!/usr/bin/env bash

function exists() {
  command -v "$1" >/dev/null 2>&1 || type -t >/dev/null 2>&1
}
