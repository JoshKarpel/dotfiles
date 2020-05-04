#!/usr/bin/env bash

function batlab_submit_workspace() {
  (_batlab_submit_workspace $@)
}

function _batlab_submit_workspace() {
  set -e

  local timestamp=$(date +'%F_%H-%M-%S')

  local tag=$1
  if [[ -z $tag ]]; then
    echo "ERROR: must provide a build tag"
    return 1
  fi

  local sha=$2
  if [[ -z $sha ]]; then
    sha="$(git write-tree)"
  fi

  local buildid="${tag}__${timestamp}__${sha}"
  echo "$buildid"

  (gr && git archive "$sha" | ssh "$batlab" cd workspace_builds '&&' mkdir "${buildid}" '&&' cd "${buildid}" '&&' tar xf - '&&' ../submit_workspace_build "${tag}")

  set +e
}