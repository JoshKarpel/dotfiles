---
paths:
  - ".github/workflows/*.yml"
  - ".github/workflows/*.yaml"
  - ".github/actions/**/*.yml"
  - ".github/actions/**/*.yaml"
---

# GitHub Actions Style Guide

## Workflow File Naming

Use lowercase with hyphens: `quality-check.yml`, `publish-package.yml`,
`publish-docs.yml`. The `name:` field at the top of the file should match the
filename (without extension).

## Triggers

CI / quality-check workflows:

```yaml
on:
  push:
    branches:
      - main
  pull_request:
  workflow_dispatch:
```

Publish workflows (triggers on GitHub Release published):

```yaml
on:
  release:
    types: [published]
```

Docs workflows (push to main, optionally manual):

```yaml
on:
  push:
    branches:
      - main
  workflow_dispatch:
```

## Concurrency

Don't add a `cancel-in-progress` concurrency group to CI by default:

```yaml
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true  # avoid: cancels in-flight CI on a new push
```

We want CI to run to completion on every commit, even when a newer commit is
pushed to the same ref, so each commit gets a real pass/fail status. Only add
`cancel-in-progress` when there's a specific reason (e.g. expensive jobs where
only the latest result matters).

## Permissions

Set `permissions: {}` at the workflow root, then grant each job only what it
needs. The default `GITHUB_TOKEN` is broad, so any compromised action in any
step inherits write access to the repo. An empty root block drops that to
nothing and makes every grant deliberate and visible.

```yaml
permissions: {}

jobs:
  test-code:
    permissions:
      contents: read
```

A `permissions:` block replaces the defaults wholesale rather than merging with
them, so a job that checks out code has to name `contents: read` itself.

## Checkout Credentials

Pass `persist-credentials: false` to `actions/checkout`. It defaults to `true`,
which writes the job's token into `.git/config`, where it outlives the step and
stays readable by everything the job runs afterward.

```yaml
- name: Check out repository
  uses: actions/checkout@<version>
  with:
    persist-credentials: false
```

Leave the default only when a later step pushes back to the repo and needs the
credential (e.g. `mkdocs gh-deploy`).

## Auditing with zizmor

Run [zizmor](https://docs.zizmor.sh) over workflows. It catches the insecure
defaults above (broad permissions, persisted credentials) along with template
injection and similar issues:

```bash
uvx zizmor .github/
```

Wire it into pre-commit (see the pre-commit style guide). In CI, the
`zizmorcore/zizmor-action` reports findings to the repo's Security tab.

zizmor's `unpinned-uses` audit defaults to demanding SHA pins, so it flags
patch-version tags. Keep the tags (see below) and relax the policy in
`zizmor.yml`:

```yaml
rules:
  unpinned-uses:
    config:
      policies:
        "*": ref-pin
```

`ref-pin` accepts any explicit tag or SHA while still flagging a floating
`@main`.

## Action Version Pinning

Pin to full patch versions, not floating major tags. `@v4` drifts; `@v4.2.2`
is reproducible. Always update to the latest available patch when writing a new
workflow.

Commonly used actions:

| Action | Purpose |
|---|---|
| `actions/checkout` | Check out repository |
| `astral-sh/setup-uv` | Install uv + Python |
| `extractions/setup-just` | Install Just |
| `pypa/gh-action-pypi-publish` | Publish to PyPI |
| `actions/upload-artifact` / `download-artifact` | Artifact passing between jobs |
| `actions/upload-pages-artifact` / `actions/deploy-pages` | GitHub Pages deploy |

Check the current release version in the action's GitHub repo before writing
the `uses:` line.

## Names

Always include `name:` on every step and job.

## Step Separation

Put a blank line between steps in a job, and between steps in a composite
action, to separate them visually. It's purely cosmetic, but it makes a long
`steps:` list much easier to scan and edit.

## Timeouts

Set `timeout-minutes` on every job, matrix or not. Runners default to a
360-minute cap, so a hung step (a wedged process, a stalled network call)
burns six hours before GitHub kills it. `timeout-minutes: 15` is a sane
default for a quick check job; raise it only for genuinely long builds.

## Quality-Check Job

Structural conventions for matrix CI jobs:

- Matrix key is `platform`, not `os`
- `fail-fast: false`, so a single failure doesn't stop other matrix legs
- `defaults.run.shell: bash` for cross-platform consistency

## Python / uv Workflow Examples

These are starting-point templates. Adapt them to the project: adjust the
Python version matrix, omit steps that don't apply, add steps as needed.

### Quality-Check Job

```yaml
jobs:
  test-code:
    strategy:
      fail-fast: false
      matrix:
        platform: [ubuntu-latest, macos-latest]
        python-version: ["3.13", "3.14"]
    defaults:
      run:
        shell: bash
    runs-on: ${{ matrix.platform }}
    timeout-minutes: 15
    permissions:
      contents: read
    env:
      PLATFORM: ${{ matrix.platform }}
      PYTHON_VERSION: ${{ matrix.python-version }}
      PYTHONUTF8: 1  # https://peps.python.org/pep-0540/
      COLORTERM: truecolor
      PIP_DISABLE_PIP_VERSION_CHECK: 1
    steps:
      - name: Check out repository
        uses: actions/checkout@<version>
        with:
          persist-credentials: false

      - name: Install Just
        uses: extractions/setup-just@<version>

      - name: Install uv
        uses: astral-sh/setup-uv@<version>
        with:
          python-version: ${{ matrix.python-version }}
          enable-cache: true

      - name: Run pre-commit checks
        run: uv run pre-commit run --all-files --show-diff-on-failure --color=always

      - name: Make sure we can build the package
        run: uv build

      - name: Test types
        run: uv run mypy

      - name: Test code
        run: uv run pytest -v --cov --cov-report=xml --durations=20

      - name: Test docs
        run: uv run mkdocs build --clean --strict --verbose
```

- `setup-uv` handles both uv and Python installation; set `enable-cache: true`
  in CI jobs (but not in publish jobs: see the PyPI section below)
- `uv build` (no `-vvv`) for the build smoke test
- Omit steps that don't apply (e.g. skip "Test docs" if there's no MkDocs site,
  skip "Install Just" if the project doesn't use Just)

### PyPI Publish Job (Trusted Publisher / OIDC)

No API token needed. Configure the trusted publisher in PyPI project settings
first, then:

```yaml
jobs:
  pypi:
    runs-on: ubuntu-latest
    environment:
      name: pypi
      url: https://pypi.org/p/${{ github.event.repository.name }}
    permissions:
      contents: read  # add default back in
      id-token: write
    steps:
      - name: Check out repository
        uses: actions/checkout@<version>
        with:
          persist-credentials: false

      - name: Install uv
        uses: astral-sh/setup-uv@<version>
        with:
          enable-cache: false  # don't restore a cache into a publish job

      - name: Build the package
        run: uv build -vvv

      - name: Publish package distributions to PyPI
        uses: pypa/gh-action-pypi-publish@<version>
```

`id-token: write` grants the OIDC exchange. The `contents: read` comment is
intentional: it restores the default that's otherwise dropped when you set any
explicit `permissions`.

Turn the cache off here, unlike in CI. A publish job builds the artifact that
ships, and a cache is writable by other workflows on the repo (a PR-triggered
run, say), so restoring one lets a poisoned entry reach the built distribution.
`setup-uv` caches by default, so `enable-cache: false` has to be explicit;
omitting the input isn't enough. The publish job runs once per release, so the
lost cache costs nothing worth having.

Trusted publishing means there's no API token to store, scope, or rotate, and
it's the prerequisite for PyPI's digital attestations. Configure the trusted
publisher on PyPI with the environment name (`pypi` above): PyPI checks the
environment claim on the incoming OIDC token, so the workflow's `environment:`
block is load-bearing, not decoration.

Add [required reviewers](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments#required-reviewers)
to that environment. Publishing is irreversible (a filename can never be reused
on PyPI), so it's worth a human gate: an accidental or malicious trigger stalls
pending approval instead of shipping. Approving your own releases still buys
something, since it demands an active, logged-in action at publish time rather
than just a push.

### MkDocs Docs Publish Job

Simple `gh-deploy` variant (deploys to `gh-pages` branch):

```yaml
jobs:
  publish-docs:
    runs-on: ubuntu-latest
    steps:
      - name: Check out repository
        uses: actions/checkout@<version>

      - name: Install uv
        uses: astral-sh/setup-uv@<version>
        with:
          enable-cache: true

      - name: Build and deploy docs
        run: uv run mkdocs gh-deploy --clean --strict --verbose --force
```
