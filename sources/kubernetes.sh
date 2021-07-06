#!/usr/bin/env bash

alias k="kubectl"
alias wk="watch kubectl"

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

  if [[ -f $ctx ]]; then
    ctx=$(realpath $ctx)
    echo "Setting KUBECONFIG=${ctx}"
    export KUBECONFIG="${ctx}"
  elif [[ -z $ctx ]]; then
    kubectl config get-contexts
  else
    kubectl config use-context "${ctx}"
  fi
}
