---
name: style-justfile
description: >
  Justfile style guide. MUST be invoked when writing or editing a justfile or Justfile.
  Covers file structure, settings, the default list recipe, doc attributes,
  aliases, variadic arguments, and command echo suppression.
---

# Justfile Style Guide

## Adopt Project Conventions First

These are defaults. See `style-programming` for the full principle.
Match what's already in the project before applying anything below.

## File Header

Always start with the shebang and common settings:

```just
#!/usr/bin/env just --justfile

set dotenv-load
set ignore-comments
```

`set ignore-comments` means `#`-prefixed lines in recipes aren't passed to the
shell. `set dotenv-load` automatically loads a `.env` file if present.

## Default Recipe

The first recipe should be the default and should list available recipes:

```just
[default]
[doc("List available recipes")]
list:
    @just --list
```

The `@` suppresses the echo of the `just --list` command itself, so only the
output is shown. Use `@` on any line where the command speaking for itself is
enough — the output is the feedback.

## Overridable Variables

Declare empty variables at the top of the file for args that callers might want
to override without changing the recipe:

```just
pytest-args := ""
mypy-args := ""

[doc("Run tests")]
test:
    uv run pytest {{ pytest-args }}
```

Callers can then do `just pytest-args="-x"` or `just pytest-args="--lf"`. The
key advantage: the variable propagates into every recipe that references it,
even transitively, so a top-level `check` recipe that depends on `test` which
calls `pytest` doesn't need to thread `*args` through every intermediate recipe.

## Recipe Style

- **kebab-case** for recipe names (`download-models`, not `downloadModels`)
- **`*args`** for recipes that accept variadic arguments passed through to a tool:

```just
[doc("Run tests")]
test *args:
    uv run pytest {{ args }}
```

- **Single-letter aliases** for frequently used recipes, preferred; a few letters
  if a single letter is unavailable or unclear:

```just
alias t := test
```

Place the alias immediately after the recipe it aliases.

## Recipe Attributes

- **`[doc("...")]`** on every recipe: this is what appears in `just --list`.
  Prefer `[doc(...)]` over the `# comment` doc-comment syntax; it's explicit and
  unambiguous.
- **`[private]`** to hide internal helper recipes from `just --list`.
  Prefer this over the `_` prefix convention.
- **`[confirm]`** (or `[confirm("Are you sure?")]`) on destructive recipes to
  require explicit confirmation before running.
- **`[parallel]`** to run a recipe's dependencies concurrently rather than
  sequentially. The recipe can still have its own commands, which run after the
  dependencies complete:

```just
[parallel]
[doc("Run all checks")]
check: test lint typecheck
    echo "all done"
```

- **`[group('name')]`** to group related recipes: they appear together under a
  header in `just --list`. A recipe can belong to multiple groups by stacking
  annotations.
- **`[linux]`** / **`[macos]`** / **`[windows]`** for platform-specific recipes
  with the same name.

## Sigils

Sigils are per-line prefixes that modify how a command runs:

- **`@`**: suppress echo of that line. Use when the command's output speaks for
  itself and printing the command would be noise. Apply to the whole recipe with
  `@recipe-name:` to flip the default.
- **`-`**: continue even if the command fails. Useful for cleanup steps where
  failure is expected and shouldn't halt the recipe (e.g., `-rm -rf dist/`).

## Bash Recipes

When writing a multi-line recipe that uses a bash shebang (i.e., `#!/usr/bin/env bash`),
load the `style-shell` skill for shell scripting conventions.

## References

- [just documentation](https://just.systems/man/en/)
