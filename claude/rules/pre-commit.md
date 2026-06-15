---
paths:
  - ".pre-commit-config.yaml"
  - ".pre-commit-config.yml"
---

# pre-commit Style Guide

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
