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

function kns() {
  local target=$1

  local current="$(kubectl config view --minify -o jsonpath='{..namespace}')"

  if [[ -z $current ]]; then
    kubectl config set-context --current --namespace="default"
    current="$(kubectl config view --minify -o jsonpath='{..namespace}')"
  fi

  local available="$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' | xargs -n 1)"

  if [[ -z "$target" ]]; then
    for ns in $(echo $available); do  # bash/zsh compatibility https://stackoverflow.com/questions/23157613/how-to-iterate-through-string-one-word-at-a-time-in-zsh
      if [[ "${current}" == "${ns}" ]]; then
        echo "* ${ns}"
      else
        echo "  ${ns}"
      fi
    done
  else
    if [[ "\b${available}\b" =~ ${target} ]]; then
      kubectl config set-context --current --namespace="${target}"
    else
      echo "No namespace named ${target}"
      echo "Available namespaces:"
      echo "${available}"
      return 1
    fi
  fi
}
