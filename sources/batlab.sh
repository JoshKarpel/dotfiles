#!/usr/bin/env bash

function batlab_submit_workspace() {
  (_batlab_submit_workspace $@)
}

function _batlab_submit_workspace() {
  set -e

  local branch=$(git_branch_name)
  local timestamp=$(date +'%F_%H-%M-%S')

  local tag=$1
  if [[ -z $tag ]]; then
    echo "ERROR: must provide a build tag"
    return 1
  fi

  local sha=$2
  if [[ -z $sha ]]; then
    sha="HEAD"
  fi

  local buildid="${timestamp}_${tag}_${sha}"
  echo "$buildid"

  git archive "$sha" | \
    tqdm --bytes | \
    ssh "$batlab" cd workspace_builds '&&' mkdir "${buildid}" '&&' cd "${buildid}" '&&' tar xf - '&&' ../submit_workspace_build "${tag}"

  set +e
}
