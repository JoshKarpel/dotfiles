#!/usr/bin/env bash

alias k="kubectl"

if exists kubectl; then
  source <(kubectl completion bash)
  complete -F __start_kubectl k
fi

function ktx() {
  local ctx=$1

  if [[ -z $ctx ]]; then
    kubectl config get-contexts
  else
    kubectl config use-context $ctx
  fi
}
