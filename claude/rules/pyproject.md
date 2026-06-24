---
paths:
  - "**/pyproject.toml"
---

# pyproject.toml Style Guide

## uv Cooldown

Set an `exclude-newer` cooldown (a relative duration) under `[tool.uv]` as a
supply-chain defense.

```toml
[tool.uv]
exclude-newer = "7 days"
```

Opt a package out with `exclude-newer-package` (registries lacking PEP 700
upload-time data, or a package you need a fresh release of):

```toml
[tool.uv]
exclude-newer = "7 days"
exclude-newer-package = { internal-pkg = false }
```

## Ruff isort

Force one import per line so diffs stay minimal: adding or removing an import
touches a single line rather than reflowing a combined `from x import a, b, c`.

```toml
[tool.ruff.lint.isort]
force-single-line = true
```

## References

- [uv resolution: exclude-newer](https://docs.astral.sh/uv/concepts/resolution/#exclude-newer)
