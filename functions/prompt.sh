#!/usr/bin/env bash

function __get_prompt_colors() {
  for x in $(__hostid); do
    echo "${BRIGHT_COLORS[$x]}"
  done
}

function prompt() {
  prompt_colors=($(__get_prompt_colors))

  local j=""
  if [[ -n "$(jobs)" ]]; then
    local j=" ${prompt_colors[3]}(\j)${RESET}"
  fi

  echo "[${prompt_colors[0]}\@${RESET} | ${prompt_colors[1]}\u@\h${RESET} | ${prompt_colors[2]}\w${RESET}]$j \$ ${RESET}"
}
