#!/usr/bin/env bash

function __get_prompt_colors() {
  for x in $(hostcolors); do
    echo "${BRIGHT_COLORS[$x]}"
  done
}


function prompt() {
  local last_command=$? # must come first!

  prompt_colors=($(__get_prompt_colors))

  local dir="\w"
  local g=""
  local j=""
  local e=""

  if [[ $last_command != 0 ]]; then
  local e=" ${prompt_colors[5]}${UNDERLINED}${last_command}${RESET}"
    fi

  if [[ -n "$(jobs)" ]]; then
    local j=" ${prompt_colors[3]}(\j)${RESET}"
  fi

  if is_inside_git_repo; then
    if ! git_repo_is_clean; then
      local dirty="!"
    fi
    local g="@${prompt_colors[4]}$(git rev-parse --abbrev-ref HEAD)$dirty${RESET}"

    local dir="$(realpath --relative-to="$(git rev-parse --show-toplevel)" "$PWD")"
    if [[ $dir == "." ]]; then
      local dir=""
    fi
    local dir="$(echo "$(git_repo_name)/$dir" | sed s'/\/$//')"
  fi


  echo "${prompt_colors[0]}\h${RESET}:${prompt_colors[1]}$dir${RESET}$g$j$e \$ ${RESET}"
}
