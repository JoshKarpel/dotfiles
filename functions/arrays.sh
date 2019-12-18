#!/usr/bin/env bash

function random_element() {
  arr=("${!1}")
  echo ${arr["$((RANDOM % ${#arr[@]}))"]}
}
