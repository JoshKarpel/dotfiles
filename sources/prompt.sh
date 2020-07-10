#!/usr/bin/env bash

function __pre_command() {
  if [ -z "$AT_PROMPT" ]; then
    return
  fi
  unset AT_PROMPT

  if [[ $DISPLAY_TIMING ]]; then
    date=$(date +"%F %r %Z")
    msg_length=${#date}
    echo -en "\e[90m\e[2A\r\e[$((COLUMNS - msg_length))C${date}\e[2B\r${RESET}"
  fi

  export LAST_COMMAND_AT=$(now)
}
trap "__pre_command" DEBUG

function __post_command() {
  AT_PROMPT=1

  #  printf "%%%$((COLUMNS - 1))s\r"

  if [[ -n "$DISPLAY_TIMING" ]]; then
    if [[ -n "$LAST_COMMAND_AT" ]]; then
      NOW=$(now)
      time_since_last_command=$((NOW - LAST_COMMAND_AT))
      msg=$(date +"%F %r %Z")
      if [[ $time_since_last_command -gt 1 ]]; then
        timing=$(humanize "$time_since_last_command")
        msg="[$timing] $msg"
      fi
      msg_length=${#msg}
      echo -e "\e[90m\r\e[$((COLUMNS - msg_length))C$msg${RESET}"
    fi
  fi

  # update history file
  history -a

  export PS1=$($PROMPT_FUNCTION)
}
PROMPT_COMMAND="__post_command"

function __get_prompt_colors() {
  for x in $(hostcolors); do
    echo "${BRIGHT_COLORS[$x]}"
  done
}

function fancy_prompt() {
  local last_exit=$? # must come first!

  prompt_colors=($(__get_prompt_colors))

  local dir="\w"
  local g=""
  local j=""
  local e=""
  local c=""

  if [[ $last_exit != 0 ]]; then
    local e=" ${prompt_colors[2]}${UNDERLINED}${last_exit}${RESET}"
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
  fi
  local pdir="${prompt_colors[1]}$dir${RESET}"

  if [[ $CONDA_DEFAULT_ENV != "base" ]]; then
    local c=" ${prompt_colors[5]}[$CONDA_DEFAULT_ENV]${RESET}"
  fi

  local user="${prompt_colors[3]}\u${RESET}"
  local host="${prompt_colors[0]}\h${RESET}"

  if [[ $TITLE_SET_MANUALLY != true ]]; then
    _set_title "$(whoami)@$(hostname):$dir \$$(fc -ln -0)"
  fi

  echo "$user@$host:$pdir$g$j$c$e${RESET}\n\$ "
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

function enable_timing_display() {
  export DISPLAY_TIMING=true
}

function disable_timing_display() {
  unset DISPLAY_TIMING
}

function use_fancy_prompt() {
  export PROMPT_FUNCTION='fancy_prompt'
}

function use_presentation_prompt() {
  export PROMPT_FUNCTION='presentation_prompt'
}
