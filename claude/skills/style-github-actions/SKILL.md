---
name: style-github-actions
description: >
  GitHub Actions workflow style guide. Use when writing or editing any
  .github/workflows/* file. Covers trigger patterns, action version pinning,
  matrix structure, step naming, PyPI trusted publishing, and docs deployment.
  Read references/python.md for Python/uv-specific examples.
---

# GitHub Actions Style Guide

## Adopt Project Conventions First

These are defaults. See `style-programming` for the full principle.
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

For language-specific examples, read [references/python.md](references/python.md).
