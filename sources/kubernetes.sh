#!/usr/bin/env bash

if exists microk8s; then
  function kubectl() {
    microk8s kubectl "$@"
  }

  function helm() {
    microk8s helm3 "$@"
  }
fi

# client-go 1.35+ (k9s 0.50.17+) does each informer's initial list as a watch-list
# stream, which the API server never gzips, so a pod view pulls every full pod
# object uncompressed (~15x the bytes of a gzipped LIST) and crawls over a VPN.
# https://github.com/derailed/k9s/issues/4044
function k9s() {
  KUBE_FEATURE_WatchListClient=false command k9s "$@"
}

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

# With no argument, ktx, kfg and kns pick one with kube-pick and then carry on as
# if it had been given; leaving the picker leaves everything as it was.
function ktx() {
  local ctx=$1

  # A picked name is always a context, even when a file in this directory shares it.
  if [[ -z $ctx ]]; then
    ctx=$(kube-pick context) || return
    kubectl config use-context "${ctx}"
  elif [[ -f $ctx ]]; then
    ctx=$(realpath $ctx)
    echo "Setting KUBECONFIG=${ctx}"
    export KUBECONFIG="${ctx}"
  else
    kubectl config use-context "${ctx}"
  fi
}

function kfg() {
  local cfg=$1

  if [[ -z $cfg ]]; then
    cfg=$(kube-pick config) || return
  fi

  echo "Setting KUBECONFIG=${HOME}/.kube/${cfg}"
  export KUBECONFIG="${HOME}/.kube/${cfg}"
}

function kns() {
  local target=$1

  if [[ -z $target ]]; then
    target=$(kube-pick namespace) || return
  fi

  kubectl config set-context --current --namespace="${target}"
}
