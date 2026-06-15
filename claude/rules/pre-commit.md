---
paths:
  - ".pre-commit-config.yaml"
  - ".pre-commit-config.yml"
---

# pre-commit Style Guide

## Repo Order and Revisions

Order `repos:` from general to language-specific: `pre-commit-hooks` first,
then `pygrep-hooks`, then `check-jsonschema`, then language formatters
(`ruff-pre-commit`). Separate each repo block with one blank line.

Pin every `rev:`. When adding a repo, omit the `rev:` and run
`pre-commit autoupdate` to fill in the current release rather than guessing.

## Air-Gapped or Firewalled CI

pre-commit clones each non-`local` hook repo from public GitHub at runtime,
which fails where CI can't reach it. In that case, in order of preference:

- Point pre-commit at an internal GitHub proxy or a fork of the upstream repo
  mirrored where CI can reach it. This preserves the upstream hook definitions,
  so only the source location changes, keeping the hook ids and pinned `rev:`.
- Install the underlying tool through the normal package manager (the same
  one the project already uses, e.g. the Python toolchain for `ruff`) and
  invoke it from a `repo: local` hook with `language: system`:

```yaml
- repo: local
  hooks:
    - id: ruff-check
      name: ruff check
      language: system
      entry: ruff check --fix
      types: [python]
```

## Base Hooks

Start from [pre-commit-hooks](https://github.com/pre-commit/pre-commit-hooks)
with this language-agnostic set:

```yaml
- repo: https://github.com/pre-commit/pre-commit-hooks
  hooks:
    - id: check-added-large-files
    - id: check-case-conflict
    - id: check-merge-conflict
    - id: check-toml
    - id: end-of-file-fixer
    - id: forbid-new-submodules
    - id: mixed-line-ending
    - id: trailing-whitespace
```

Add `check-json` when the repo has JSON files (exclude JSONC like
`tsconfig.json`, which isn't strict JSON), and `detect-private-key` to guard
against committed keys.

This repo also ships Python-only hooks (`check-ast`, `check-builtin-literals`,
`check-docstring-first`, `debug-statements`). Don't add them reflexively: see
the Python Hooks section, since ruff covers most of them.

## Python Hooks

For Python projects, add [pygrep-hooks](https://github.com/pre-commit/pygrep-hooks)
and [ruff-pre-commit](https://github.com/astral-sh/ruff-pre-commit). The ruff
hook formats and lints; its rule selection lives in `pyproject.toml` (see the
Python style guide). Run `ruff-format` before `ruff-check` so lint fixes apply
to already-formatted code.

Prefer ruff lints over the Python-only `pre-commit-hooks` entries.

```yaml
- repo: https://github.com/astral-sh/ruff-pre-commit
  hooks:
    - id: ruff-format
    - id: ruff-check
      args: [--fix]
```

## Schema Validation

When the repo has GitHub config under `.github/`, add the
[check-jsonschema](https://github.com/python-jsonschema/check-jsonschema)
hooks that validate those files against their published schemas:

```yaml
- repo: https://github.com/python-jsonschema/check-jsonschema
  hooks:
    - id: check-dependabot
    - id: check-github-workflows
    - id: check-github-actions
```
