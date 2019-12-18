#!/usr/bin/env bash

function is_inside_git_repo() {
  git rev-parse --show-toplevel >/dev/null 2>&1
}

function git_repo_name() {
  basename "$(git rev-parse --show-toplevel)"
}

function git_repo_is_clean() {
  git diff-index --quiet HEAD
}

HASH="%C(yellow)%h%C(reset)"
RELATIVE_TIME="%C(green)%<(15,trunc)%ar%C(reset)"
AUTHOR="%C(bold blue)%<(15,trunc)%an%C(reset)"
REFS="%C(bold red)%d%C(reset)"
SUBJECT="%s"

FORMAT="}$HASH}$RELATIVE_TIME}$AUTHOR}$REFS $SUBJECT"

function pretty_git_log() {
  git --no-pager log --color=always --pretty=tformat:"$FORMAT" --graph $* |
    column -t -s '}' |
    git_page_maybe
}

function git_page_maybe() {
  if [ -n "$GIT_NO_PAGER" ]; then
    cat
  else
    less --quit-if-one-screen --no-init --RAW-CONTROL-CHARS --chop-long-lines
  fi
}
