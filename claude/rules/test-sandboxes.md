---
paths:
  - "**/test_*"
  - "**/*_test.*"
  - "**/*.test.*"
  - "**/tests/**"
  - "**/test/**"
  - "**/conftest.py"
---

# Test Sandboxes

- **Isolate a sandbox from the user's own config.** A throwaway `git init` repo
  still reads the global gitconfig and global ignore file, so a fixture named
  `fixture.bin` can be silently untracked by a `*.bin` pattern, failing the
  test for a reason in nobody's code. `GIT_CONFIG_GLOBAL=/dev/null` alone
  doesn't fix it: with no config setting `core.excludesFile`, git falls back to
  `$XDG_CONFIG_HOME/git/ignore` (or `~/.config/git/ignore`), so point
  `XDG_CONFIG_HOME` or `HOME` at the sandbox as well. Any tool with a
  user-level config directory needs the same treatment.
