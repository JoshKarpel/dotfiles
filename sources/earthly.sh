#!/usr/bin/env bash

alias e="earthly"

function els() {
  find . -name Earthfile -exec earthly ls --long {} \;
}
