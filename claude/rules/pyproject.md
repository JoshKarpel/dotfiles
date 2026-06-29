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

## Ruff

Use `line-length = 120`. Select broadly; each selected group links its
documentation, and each ignore states its rationale. `isort.force-single-line`
keeps one import per line so adding or removing an import touches a single line
rather than reflowing a combined `from x import a, b, c`.

```toml
[tool.ruff]
line-length = 120

[tool.ruff.lint]
select = [
    "A",     # https://docs.astral.sh/ruff/rules/#flake8-builtins-a
    "ASYNC", # https://docs.astral.sh/ruff/rules/#flake8-async-async
    "B",     # https://docs.astral.sh/ruff/rules/#flake8-bugbear-b
    "BLE",   # https://docs.astral.sh/ruff/rules/#flake8-blind-except-ble
    "C4",    # https://docs.astral.sh/ruff/rules/#flake8-comprehensions-c4
    "D",     # https://docs.astral.sh/ruff/rules/#pydocstyle-d
    "DTZ",   # https://docs.astral.sh/ruff/rules/#flake8-datetimez-dtz
    "E",     # https://docs.astral.sh/ruff/rules/#error-e
    "F",     # https://docs.astral.sh/ruff/rules/#pyflakes-f
    "FA",    # https://docs.astral.sh/ruff/rules/#flake8-future-annotations-fa
    "FLY",   # https://docs.astral.sh/ruff/rules/#flynt-fly
    "FURB",  # https://docs.astral.sh/ruff/rules/#refurb-furb
    "G",     # https://docs.astral.sh/ruff/rules/#flake8-logging-format-g
    "I",     # https://docs.astral.sh/ruff/rules/#isort-i
    "ICN",   # https://docs.astral.sh/ruff/rules/#flake8-import-conventions-icn
    "LOG",   # https://docs.astral.sh/ruff/rules/#flake8-logging-log
    "N",     # https://docs.astral.sh/ruff/rules/#pep8-naming-n
    "PERF",  # https://docs.astral.sh/ruff/rules/#perflint-perf
    "PGH",   # https://docs.astral.sh/ruff/rules/#pygrep-hooks-pgh
    "PIE",   # https://docs.astral.sh/ruff/rules/#flake8-pie-pie
    "PLC",   # https://docs.astral.sh/ruff/rules/#convention-plc
    "PLE",   # https://docs.astral.sh/ruff/rules/#error-ple
    "PLW",   # https://docs.astral.sh/ruff/rules/#warning-plw
    "PT",    # https://docs.astral.sh/ruff/rules/#flake8-pytest-style-pt
    "PTH",   # https://docs.astral.sh/ruff/rules/#flake8-use-pathlib-pth
    "PYI",   # https://docs.astral.sh/ruff/rules/#flake8-pyi-pyi
    "RET",   # https://docs.astral.sh/ruff/rules/#flake8-return-ret
    "RSE",   # https://docs.astral.sh/ruff/rules/#flake8-raise-rse
    "RUF",   # https://docs.astral.sh/ruff/rules/#ruff-specific-rules-ruf
    "SIM",   # https://docs.astral.sh/ruff/rules/#flake8-simplify-sim
    "SLF",   # https://docs.astral.sh/ruff/rules/#flake8-self-slf
    "T10",   # https://docs.astral.sh/ruff/rules/#flake8-debugger-t10
    "T20",   # https://docs.astral.sh/ruff/rules/#flake8-print-t20
    "TID",   # https://docs.astral.sh/ruff/rules/#flake8-tidy-imports-tid
    "UP",    # https://docs.astral.sh/ruff/rules/#pyupgrade-up
    "W",     # https://docs.astral.sh/ruff/rules/#warning-w
]

ignore = [
    "E501",  # line length: formatter owns this
    "E741",  # ambiguous variable name: occasionally fine (e.g. l in math)
    "T201",  # print: allowed in CLIs and scripts
    "T203",  # pprint: same
    "N818",  # exception names are deliberately descriptive (e.g. ClientDisconnect), not Error-suffixed
    "G004",  # logging-f-string: f-strings in log calls are allowed (readability over lazy %-formatting)
    # pydocstyle: enforce well-formed docstrings, but don't mandate their presence or dictate mood.
    "D1",    # undocumented-*: docstrings are written where they add value (and never on modules, per house style)
    "D203",  # incompatible with D211 (no blank line before a class docstring)
    "D205",  # would force a single-physical-line summary; summary sentences wrap naturally over a few lines
    "D212",  # incompatible with D213 (the multi-line summary belongs on the second line)
    "D401",  # non-imperative-mood: descriptive docstrings are fine ("Whether ...", "A ... paired with ...")
]

[tool.ruff.lint.isort]
force-single-line = true

[tool.ruff.lint.per-file-ignores]
"**/tests/**" = [
    "SLF001",   # tests inspect private internals deliberately (white-box checks)
    "ASYNC110", # tests poll observed state with sleep loops; no Event to await
    "SIM117",   # nested `with` expresses resource scoping; flattening moves scoped asserts
]
```

Only add an ignore if you have a concrete reason; don't suppress speculatively.

## References

- [uv resolution: exclude-newer](https://docs.astral.sh/uv/concepts/resolution/#exclude-newer)
