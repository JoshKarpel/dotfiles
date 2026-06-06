---
name: style-shell
description: >
  Shell/Bash style guide. Use when writing or editing any .sh file, bin/
  script, hook script, or sourced shell helper. Covers file headers, safety
  flags, indentation, functions, quoting, and toolchain.
---

# Shell / Bash Style Guide

## Adopt Project Conventions First

These are defaults. See `style-programming` for the full principle.
Match what's already in the project before applying anything below.

## File Header

Every standalone script starts with a bash shebang and safety flags:

```bash
#!/usr/bin/env bash

set -euo pipefail
```

- `-e` — exit immediately on any command returning a non-zero status.
- `-u` — treat unset variables as errors (prevents silent empty-string expansions).
- `-o pipefail` — a pipeline fails if any stage fails, not just the last one.

For short scripts where none of those would trigger, the flags are still worth
including — they're defensive and cheap.

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

## Toolchain

- **[`just`](https://just.systems/man/en/)** as the command runner for project tasks, recipes can be inline bash scripts

## References

- [bash manual](https://www.gnu.org/software/bash/manual/)
