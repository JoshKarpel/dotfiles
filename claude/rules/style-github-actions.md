---
paths:
  - ".github/workflows/*.yml"
  - ".github/workflows/*.yaml"
---

# GitHub Actions Style Guide

## Adopt Project Conventions First

These are defaults. See the general programming style guide for the full principle.
Match what's already in the project before applying anything below.

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

## Quality-Check Job

Structural conventions for matrix CI jobs:

- Matrix key is `platform`, not `os`
- `fail-fast: false` — don't stop other matrix legs on a single failure
- `defaults.run.shell: bash` for cross-platform consistency
- `timeout-minutes: 15` on the job

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
    env:
      PLATFORM: ${{ matrix.platform }}
      PYTHON_VERSION: ${{ matrix.python-version }}
      PYTHONUTF8: 1  # https://peps.python.org/pep-0540/
      COLORTERM: truecolor
      PIP_DISABLE_PIP_VERSION_CHECK: 1
    steps:
      - name: Check out repository
        uses: actions/checkout@<version>
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

- `setup-uv` handles both uv and Python installation; always set `enable-cache: true`
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
      - name: Install uv
        uses: astral-sh/setup-uv@<version>
        with:
          enable-cache: true
      - name: Build the package
        run: uv build -vvv
      - name: Publish package distributions to PyPI
        uses: pypa/gh-action-pypi-publish@<version>
```

`id-token: write` grants the OIDC exchange. The `contents: read` comment is
intentional: it restores the default that's otherwise dropped when you set any
explicit `permissions`.

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
