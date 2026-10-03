---
paths:
  - ".pre-commit-config.yaml"
  - ".pre-commit-config.yml"
---

# pre-commit Style Guide

## pre-commit Runs Hooks; It Doesn't Install Them

Every hook is a `repo: local` hook with `language: unsupported`, whose `entry`
runs a tool the repo already installs (see the supply-chain rule for where each
tool comes from). Never add a remote `repo:` with a `rev:`, which makes
pre-commit a second package manager with its own copy of each tool.

With nothing to fetch or build, pre-commit only runs commands:

- **One version per tool.** The editor, the task runner, the hook and CI all run
  the version in the lockfile, rather than a `rev:` that drifts from it.
- **The cooldown covers the hooks.** uv's `exclude-newer` and mise's
  `minimum_release_age` apply to everything they resolve; a `rev:` gets none.
- **No hook environments.** The setup that installs the project's tools covers
  every hook, so a commit works offline and `--install-hooks` has nothing to do.

`language: unsupported` (the current name for `system`) needs pre-commit 4.4.0
or newer. Install pre-commit itself the same way as the tools it runs.

Prefix each `entry` with the command that runs a tool from its installer:

- **uv dev group:** `uv run --frozen <tool>`. A bare `uv run` re-locks when
  `pyproject.toml` has changed, so a commit that edits a dependency without
  re-locking tries to resolve over the network; `--frozen` uses the lock as it
  stands, and the `uv lock` hook catches a stale one.
- **mise:** `mise exec -- <tool>`, which resolves the version in `mise.toml`
  whether or not the shell that ran `git commit` activated mise.

Update hooks the way you update the tools (`uv lock --upgrade`, `mise lock`),
not with `pre-commit autoupdate`, which only knows about `rev:`s.

## Copying Upstream Hook Definitions

A local hook replaces upstream's, so copy its definition from the
`.pre-commit-hooks.yaml` in the upstream repo at the installed version: `entry`,
`files`, `types`/`types_or`, `args`, `require_serial` and `pass_filenames`. The
`entry` is the console script, which is not always the hook id: the
`trailing-whitespace` hook runs `trailing-whitespace-fixer`.

The copy doesn't follow upstream. When a version bump changes a hook's `files`
or `args`, nothing reports it, so recheck the upstream definitions on a major
version bump.

## Hook Order

Order hooks from general to language-specific: the base hooks, then schema
validation and workflow auditing, then language formatters and linters.

## Base Hooks

Start from the [pre-commit-hooks](https://github.com/pre-commit/pre-commit-hooks)
package with this language-agnostic set (shown with uv; under mise, only the
`entry` prefix changes):

```yaml
- repo: local
  hooks:
    - id: check-added-large-files
      name: check for added large files
      language: unsupported
      entry: uv run --frozen check-added-large-files
    - id: check-case-conflict
      name: check for case conflicts
      language: unsupported
      entry: uv run --frozen check-case-conflict
    - id: check-merge-conflict
      name: check for merge conflicts
      language: unsupported
      entry: uv run --frozen check-merge-conflict
      types: [text]
    - id: check-toml
      name: check toml
      language: unsupported
      entry: uv run --frozen check-toml
      types: [toml]
    - id: end-of-file-fixer
      name: fix end of files
      language: unsupported
      entry: uv run --frozen end-of-file-fixer
      types: [text]
    - id: forbid-new-submodules
      name: forbid new submodules
      language: unsupported
      entry: uv run --frozen forbid-new-submodules
      types: [directory]
    - id: mixed-line-ending
      name: mixed line ending
      language: unsupported
      entry: uv run --frozen mixed-line-ending
      types: [text]
    - id: trailing-whitespace
      name: trim trailing whitespace
      language: unsupported
      entry: uv run --frozen trailing-whitespace-fixer
      types: [text]
```

Add `check-json` (`types: [json]`) when the repo has JSON files (exclude JSONC
like `tsconfig.json`, which isn't strict JSON), and `detect-private-key`
(`types: [text]`) to guard against committed keys.

The package also ships Python-only checks (`check-ast`, `check-builtin-literals`,
`check-docstring-first`, `debug-statements`). Don't add them reflexively: ruff
covers most of them.

## Python Hooks

For Python projects, keep the lock current and run
[ruff](https://docs.astral.sh/ruff/), which formats and lints; its rule selection
lives in `pyproject.toml` (see the Python style guide), and its `PGH` rules cover
what `pygrep-hooks` would. Run `ruff format` before `ruff check` so lint fixes
apply to already-formatted code.

```yaml
- repo: local
  hooks:
    - id: uv-lock
      name: uv lock
      language: unsupported
      entry: uv lock
      files: ^(uv\.lock|pyproject\.toml|uv\.toml)$
      pass_filenames: false
    - id: ruff-format
      name: ruff format
      language: unsupported
      entry: uv run --frozen ruff format --force-exclude
      types_or: [python, pyi, jupyter]
      require_serial: true
    - id: ruff-check
      name: ruff check
      language: unsupported
      entry: uv run --frozen ruff check --force-exclude --fix
      types_or: [python, pyi, jupyter]
      require_serial: true
```

## Generated Code

When part of a file is generated (e.g. an overload ladder produced by
[cog](https://nedbatchelder.com/code/cog/)), regenerate it from its single
source in a hook instead of hand-editing the output or letting it drift. Have
that one hook run the generator *and then* the formatter, in a single script: a
raw generator emits unformatted code, so if the formatter is a separate hook the
two fight (the generated output never matches what the formatter would produce,
and hook ordering and re-runs churn over it). Running generator-then-formatter
in one script emits already-formatted code before pre-commit inspects it:

```yaml
- repo: local
  hooks:
    - id: regenerate-ladders
      name: regenerate overload ladders (cog + ruff)
      language: unsupported
      entry: tools/regenerate.sh
      files: ^src/pkg/(handlers|extractors)\.py$
```

Don't add a separate `--check` mode: pre-commit already fails the run whenever a
hook modifies a tracked file, so regenerating in place *is* the check. Scope the
hook with `files:` to just the generated outputs so it doesn't fire on unrelated
commits. This is the declarative "recovered, not restated" principle (see the
declarative rule) applied to codegen: the generator owns the shape, the
checked-in file is derived.

## Hooks That Create Files

pre-commit decides a hook "modified files" by diffing the worktree against the
index, so a hook that generates a *new* file has to stage it with
`git add --intent-to-add`. A plain `git add` stages the content in full, which
leaves no unstaged diff, and the run passes silently the very first time, which
is exactly the run that should have failed. Intent-to-add registers the path
without its content, so the file still reads as an unstaged new-file diff and
the run fails like any other autofixing hook.

```bash
git add --intent-to-add "$generated"
```

## Schema Validation

When the repo has GitHub config under `.github/`, validate it against the
published schemas with
[check-jsonschema](https://github.com/python-jsonschema/check-jsonschema):

```yaml
- repo: local
  hooks:
    - id: check-dependabot
      name: validate Dependabot config
      language: unsupported
      entry: uv run --frozen check-jsonschema --builtin-schema vendor.dependabot
      files: ^\.github/dependabot\.(yml|yaml)$
      types: [yaml]
    - id: check-github-workflows
      name: validate GitHub workflows
      language: unsupported
      entry: uv run --frozen check-jsonschema --builtin-schema vendor.github-workflows
      files: ^\.github/workflows/[^/]+$
      types: [yaml]
    - id: check-github-actions
      name: validate GitHub actions
      language: unsupported
      entry: uv run --frozen check-jsonschema --builtin-schema vendor.github-actions
      files: ^(action|\.github/actions/(.+/)?action)\.(yml|yaml)$
      types: [yaml]
```

## Workflow Auditing

Pair the schema hooks with [zizmor](https://docs.zizmor.sh), which audits
workflows for insecure defaults rather than shape (see the GitHub Actions style
guide for the findings it catches and the config it needs):

```yaml
- repo: local
  hooks:
    - id: zizmor
      name: zizmor
      language: unsupported
      entry: uv run --frozen zizmor --no-progress
      files: (^|/)(\.github/(workflows/[^/]+|dependabot)\.ya?ml|action\.ya?ml|\.pre-commit-(config|hooks)\.ya?ml)$
      types: [yaml]
      require_serial: true
```
