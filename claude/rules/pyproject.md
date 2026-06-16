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

## References

- [uv resolution: exclude-newer](https://docs.astral.sh/uv/concepts/resolution/#exclude-newer)
