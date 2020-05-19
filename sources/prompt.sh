#!/usr/bin/env bash

function __get_prompt_colors() {
  for x in $(hostcolors); do
    echo "${BRIGHT_COLORS[$x]}"
  done
}

function fancy_prompt() {
  local last_command=$? # must come first!

  prompt_colors=($(__get_prompt_colors))

  local dir="\w"
  local g=""
  local j=""
  local e=""
  local c=""

  if [[ $last_command != 0 ]]; then
    local e=" ${prompt_colors[2]}${UNDERLINED}${last_command}${RESET}"
  fi

  if [[ -n "$(jobs)" ]]; then
    local j=" ${prompt_colors[3]}(\j)${RESET}"
  fi

  if is_inside_git_repo; then
    #    if ! git_repo_is_clean; then
    #      local dirty="!"
    #    fi
    local dirty=""
    local g="@${prompt_colors[4]}$(git_branch_name)$dirty${RESET}"

    local dir="$(realpath --relative-to="$(git_root)" "$PWD")"
    if [[ $dir == "." ]]; then
      local dir=""
    fi
    local dir="$(echo "$(git_repo_name)/$dir" | sed s'/\/$//')"
    local pdir="${prompt_colors[1]}$dir${RESET}"
  fi

  if [[ $CONDA_DEFAULT_ENV != "base" ]]; then
    local c=" ${prompt_colors[5]}[$CONDA_DEFAULT_ENV]${RESET}"
  fi

  local user="${prompt_colors[3]}\u${RESET}"
  local host="${prompt_colors[0]}\h${RESET}"

  if [[ ! $TITLE_SET_MANUALLY ]]; then
    _set_title "$(whoami)@$(hostname):$dir"
  fi

  echo "$user@$host:$pdir$g$j$c$e${RESET}\n\$ "
}

function use_fancy_prompt() {
  export PROMPT_COMMAND='export PS1=$(fancy_prompt)'
}

function presentation_prompt() {
  prompt_colors=($(__get_prompt_colors))

  local dir="\w"

  if is_inside_git_repo; then
    local dir="$(realpath --relative-to="$(git rev-parse --show-toplevel)" "$PWD")"
    if [[ $dir == "." ]]; then
      local dir=""
    fi
    local dir="$(echo "$(git_repo_name)/$dir" | sed s'/\/$//')"
    local dir="${prompt_colors[1]}$dir${RESET} "
  fi

  echo "$dir${RESET}\n\$ "
}

function use_presentation_prompt() {
  export PROMPT_COMMAND='export PS1=$(presentation_prompt)'
}

use_fancy_prompt
