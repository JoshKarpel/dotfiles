#!/usr/bin/env bash

function is_uv_project() {
  [[ -f "$(git root)/uv.lock" ]]
}
