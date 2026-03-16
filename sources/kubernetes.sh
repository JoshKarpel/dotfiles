#!/usr/bin/env bash

if exists microk8s; then
  function kubectl() {
    microk8s kubectl "$@"
  }

  function helm() {
    microk8s helm3 "$@"
  }
fi

alias k="kubectl"
alias wk="watch kubectl"
alias h="helm"
alias k9="k9s"
alias kk="k9s"

alias kge="kubectl get events --sort-by='.lastTimestamp'"

if exists kubectl; then
  case $(shell) in
    "bash")
      . <(kubectl completion bash)
      complete -F __start_kubectl k
      complete -F __start_kubectl wk
      ;;
    "zsh")
      . <(kubectl completion zsh)
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

function kfg() {
  local cfg=$1

  if [[ -z $cfg ]]; then
    for f in ~/.kube/*; do
      [[ -f $f ]] && echo "${f##*/}"
    done
  else
    echo "Setting KUBECONFIG=${HOME}/.kube/${cfg}"
    export KUBECONFIG="${HOME}/.kube/${cfg}"
  fi
}

function kns() {
  local target=$1

  kubectl config set-context --current --namespace="${target}"
}
