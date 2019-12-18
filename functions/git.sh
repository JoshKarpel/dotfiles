function is_inside_git_repo() {
  git rev-parse --show-toplevel > /dev/null 2>&1
}

function git_repo_name() {
  basename "$(git rev-parse --show-toplevel)"
}

function git_repo_is_clean() {
  git diff-index --quiet HEAD
}
