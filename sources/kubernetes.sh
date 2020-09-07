#!/usr/bin/env bash

alias k="kubectl"

if exists kubectl; then
  case $(shell) in
  "bash")
    source <(kubectl completion bash)
    ;;
  "zsh")
    source <(kubectl completion zsh)
    ;;
  esac

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
