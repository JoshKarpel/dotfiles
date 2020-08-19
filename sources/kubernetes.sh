#!/usr/bin/env bash

alias k="kubectl"

function ktx() {
  local ctx=$1

  if [[ -z $ctx ]]; then
    kubectl config get-contexts
  else
    kubectl config use-context $ctx
  fi
}
