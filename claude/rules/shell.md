---
paths:
  - "**/*.sh"
  - "**/*.bash"
  - "**/*.zsh"
  - "bin/**"
  - "**/*justfile*"
  - "**/*Justfile*"
---

# Shell / Bash Style Guide

## File Header

Every standalone script starts with a bash shebang and safety flags:

```bash
#!/usr/bin/env bash

set -euo pipefail
```

- `-e`: exit immediately on any command returning a non-zero status.
- `-u`: treat unset variables as errors (prevents silent empty-string expansions).
- `-o pipefail`: a pipeline fails if any stage fails, not just the last one.

For short scripts where none of those would trigger, the flags are still worth
including; they're defensive and cheap.

## Indentation

2 spaces.

## Quoting and Safety

- Always quote variable expansions: `"$var"`, `"${var}"`.
- Use `[[ ]]` for conditionals instead of `[ ]`: it handles empty strings
  and unquoted variables more safely.
- Prefer `$(...)` over backticks for command substitution: it nests cleanly.

## Functions

```bash
my_function() {
  local arg="$1"
  # ...
}
```

Declare variables `local` inside functions to avoid polluting the outer scope.
Keep functions focused; if a function grows past ~20 lines, consider splitting it.

## Guarding on Command Availability

Before calling an optional tool, check whether it's present:

```bash
if command -v jq >/dev/null 2>&1; then
  echo "$payload" | jq '.key'
fi
```

## Expected Non-Zero Exits

Under `set -e`, a command that returns non-zero for a normal, expected
outcome (`grep` finding no match, `diff` finding a difference) aborts the
script immediately, before any downstream guard clause gets a chance to run.
Guard these explicitly so execution reaches the code meant to handle the
"not found" case:

```bash
grep -q "pattern" "$file" || dir=""     # no match isn't a failure
diff -q a b >/dev/null || true          # "different" is a valid outcome
```

The bug is easy to miss: the very next line looks like it handles the case
(an `if`, a `[ -z ... ]`), but the script never reaches it because the shell
already exited.

## Exec for Long-Running Commands

`exec` the final command in a script or `just` recipe that hands off to a
long-running process (a dev server, a watcher):

```bash
exec uv run uvicorn app:app --reload
```

Without `exec`, the shell stays alive as the parent process and intercepts
signals like Ctrl-C before they reach the child; `exec` replaces the shell
with the command so the terminal talks to the actual process directly.

## Toolchain

- **[`just`](https://just.systems/man/en/)** as the command runner for project tasks;
  recipes can be inline bash scripts

## References

- [bash manual](https://www.gnu.org/software/bash/manual/)
