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

# } delimits columns
# { is the marker for the sed below that cleans up relative times
HASH="%C(cyan)%h%C(reset)"
RELATIVE_TIME="%C(bold green)%ar{%C(reset)"
AUTHOR="%C(bold cyan)%an%C(reset)"
REFS="%C(bold red)%d%C(reset)"
SUBJECT="%s"

FORMAT="}$HASH}$RELATIVE_TIME}$AUTHOR}$REFS $SUBJECT"

function pretty_git_log() {
  git --no-pager log --color=never --pretty=tformat:"$FORMAT" --graph $* |
    clean_relative_times |
    column -t -s '}' |
    git_page_maybe
}

# replace 2 years ago} with 2 years{
REMOVE_AGO='s/(^[^<]*) ago\{/\1{/'
# replace 2 years, 5 months{ with 2 years{
REMOVE_MONTHS='s/(^[^<]*), [[:digit:]]+ .*months?\{/\1{/'
# strip the } from the final output
REMOVE_PARENS='s/\{//g'
function clean_relative_times() {
  sed -E -e "$REMOVE_AGO" -e "$REMOVE_MONTHS" -e "$REMOVE_PARENS"
}

function git_page_maybe() {
  if [ -n "$GIT_NO_PAGER" ]; then
    cat
  else
    less --quit-if-one-screen --no-init --RAW-CONTROL-CHARS --chop-long-lines
  fi
}
