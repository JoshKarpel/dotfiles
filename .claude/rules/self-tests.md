---
paths:
  - "bin/**"
  - ".pre-commit-config.yaml"
---

# Hook Self-Tests

A hook with non-trivial matching or side effects carries its own tests, gated on the
`CLAUDE_HOOK_SELFTEST` environment variable so nothing pollutes its real arguments.
Run a hook's tests with `CLAUDE_HOOK_SELFTEST=1 <hook-name>`; it prints results and
exits 0 (pass) or 1 (fail). Keep the harness embedded in the hook rather than
factored into a shared script: a hook should stay self-contained and
copy-pasteable, and a small duplicated harness is a better trade than a hidden
dependency.

Each participating hook carries a `# CLAUDE_HOOK_SELFTEST` marker comment line, at
column 0, as an explicit declaration. The `claude-hook-selftests` runner discovers the
set from those markers, so there's no separate list to drift. It's wired into
pre-commit (`files: ^bin/`), so a hook regression fails the commit. Given the changed
files, it runs only the hooks that name a changed script outside a comment, directly
or through a chain of other scripts, all in parallel; with no arguments, as in CI's
`--all-files` run, or when the runner itself changed, it runs every one. A missing dependency (`jq`,
`python3`) surfaces as a failed run rather than a silent pass, since the hook whose
tests can't run exits non-zero.

- **Bash hooks** embed a block right after the `set` line, before reading stdin. A
  matching hook defines a `t <want-exit> <command>` helper that re-invokes the hook
  (`CLAUDE_HOOK_SELFTEST= "$0"`) with a crafted `{tool_input:{command:…}}` payload and
  asserts the exit code; `claude-http-server-bind-check` is the copy-paste template.
  Where branches share an exit code, assert the side effect instead: `claude-stop`
  stubs the checks and announcers it calls on PATH and compares the set that recorded
  a call, which is what distinguishes a check that blocked from one that passed when
  both exit 0. Where the exit code is the same across branches
  but what the hook says differs, assert on the text: `claude-gh-status` exits 0 whether
  or not it has anything to report, so its helpers capture the output and match a
  substring that only the branch under test prints.
- **Python hooks** check the env var in `main()` and run an embedded case matrix
  against a pure `(command, cwd, repo_root) -> …` function, so the tests need no git
  or filesystem. See `claude-rm-scope-check`.
- External state is a reason to stub, not a reason to skip. Where a hook consults the
  world through PATH, a stub directory prepended to PATH is enough, and any variable
  whose ambient value would decide a case has to be unset in the test environment.
  Where a hook needs a specific git repo,
  building one with `git init` in a `mktemp -d` sandbox and `cd`-ing into it before
  re-invoking the hook is enough: `claude-git-dash-c-check` does this to test
  blocking on the repo root, on `.`, and from a subdirectory, while allowing a
  different repo. `claude-uv-check` uses the same sandbox, `touch`-ing a `uv.lock`
  in one repo and not the other so the fixture covers both the "not a uv project"
  and "python invoked directly" branches. Run from a `git commit` hook, git's own
  `GIT_DIR` and `GIT_INDEX_FILE` would point every sandbox back at this clone,
  so `claude-hook-selftests` clears them before running anything; a self-test
  reached only through it needs no guard of its own. A sandbox repo still reads
  the global gitconfig and ignore file, so a fixture can be silently ignored by a
  pattern in nobody's code. `GIT_CONFIG_GLOBAL=/dev/null` alone doesn't stop it:
  with no `core.excludesFile` set, git falls back to `$XDG_CONFIG_HOME/git/ignore`
  (or `~/.config/git/ignore`), so point `HOME` and `XDG_CONFIG_HOME` at the
  sandbox too, as `claude-wait-checks` does.
- The installed environment is ambient state too, and CI has none of it: no `dotfiles/bin`
  on PATH and no gitconfig, so a hook that calls a sibling script by name reaches nothing
  and its guard clause passes every case. A hook that shells out to `bin/` prepends its own
  directory to PATH in the self-test (`claude-uv-check`), and a `bin/` script spells out the
  git plumbing rather than using a gitconfig alias (`is-uv-project`, `is-pre-commit-project`
  call `git rev-parse --show-toplevel`, not `git root`). Both failures are invisible locally,
  where PATH and gitconfig are installed, so a green local run says nothing about either.
- A passing self-test that cannot fail is worth nothing, so confirm a new case catches
  a deliberately broken copy of the hook before trusting it.
