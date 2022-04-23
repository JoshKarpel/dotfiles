#!/usr/bin/env bash

if exists kubecolor; then
  alias k="kubecolor"
  alias wk="watch kubecolor"
else
  alias k="kubectl"
  alias wk="watch kubectl"
fi

if exists kubectl; then
  case $(shell) in
    "bash")
      source <(kubectl completion bash)
      complete -F __start_kubectl k
      complete -F __start_kubectl wk
      ;;
    "zsh")
      source <(kubectl completion zsh)
      ;;
  esac
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

alias h="helm"
