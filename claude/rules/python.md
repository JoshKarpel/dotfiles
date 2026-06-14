---
paths:
  - "**/*.py"
  - "**/pyproject.toml"
---

# Python Style Guide

## Type Annotations

Always annotate functions. Use modern syntax (Python 3.10+):

- `X | None` not `Optional[X]`
- `X | Y` not `Union[X, Y]`
- `list[X]`, `dict[K, V]`, `tuple[X, Y]` not the `typing` equivalents
- Add `from __future__ import annotations` at the top of any file that
  needs forward references

Annotate instance variables as class-level fields on dataclasses,
or in `__init__` for plain classes. Return type is always required.

Never use `Any`. When the type isn't known, use `object`: it accepts anything,
but forces callers to narrow with `isinstance` before use, so the type checker
keeps working for you. `Any` silently disables checking wherever it spreads.

## Data Containers

| Use | When |
|---|---|
| `@dataclass(frozen=True, slots=True)` | Default: prefer immutable value objects |
| `@dataclass(slots=True)` | Only when mutation is genuinely required |
| `NamedTuple` | Only when tuple unpacking is genuinely required (should be rare) |
| `TypedDict` | Smell: only when an existing API forces a bare dict shape |
| Plain `dict` | Truly dynamic keys or quick one-off mappings |

Avoid plain classes. Strongly prefer dataclasses; if you would have put logic in
`__init__`, use a `@classmethod` factory instead. Default to frozen+slotted.
Prefer Pydantic over `TypedDict` for any validated or serialized data;
reach for `TypedDict` only when you genuinely can't control the shape.

## Strings

- **f-strings** for all string formatting, including logging calls. No `.format()` or `%`.
  (The conventional advice to use `%`-style in logging to defer interpolation is rarely
  a meaningful optimization in practice.)

## Docstrings

- **Never write module-level docstrings.** The module's name and contents
  already document it; a top-of-file docstring is noise that drifts out of
  date. (See the comments rule: capture the non-obvious *why*, never the
  obvious *what*.)

## Collections and Iteration

- **Comprehensions** for transformations. Use a plain `for` loop when there are side
  effects or when the loop's purpose isn't to produce transformed output. If the
  expression is too long, factor out a helper function; don't switch to a loop.
- **Generators** (`yield`) when the caller doesn't need all values at once
  or when materializing the sequence would waste memory.
- **Reach for `collections` and [`more-itertools`](https://more-itertools.readthedocs.io/)
  before hand-rolling loops.** A named building block usually expresses the intent more
  clearly than an accumulator and a `for` loop: `Counter`, `defaultdict`, and `deque`
  from `collections`; `chunked`, `partition`, `flatten`, `unique_everseen`, `first`,
  and `windowed` from `more-itertools`. If you're tallying, grouping, batching, or
  sliding a window, there's likely a tool for it.

## Resources

- **`pathlib.Path`** for all file paths, including in async code. No `os.path`.
  If file I/O needs to move off the event loop, wrap it with `asyncio.to_thread`
  rather than reaching for `aiofiles` or `anyio`. Those libraries do the same
  thing internally but with significantly more overhead.
- **Context managers** (`with`) for all resources: files, locks, connections,
  temporary directories.

## Secrets

Wrap secret values (API keys, passwords, tokens) in Pydantic's
[`SecretStr`](https://docs.pydantic.dev/latest/api/types/#pydantic.types.SecretStr)
rather than passing them around as plain `str`. `SecretStr` redacts the value
from `repr()`, logs, tracebacks, and model dumps, so a stray log line or error
report can't leak it; call `.get_secret_value()` only at the point of use. Load
secrets and config together with
[`pydantic-settings`](https://docs.pydantic.dev/latest/concepts/pydantic_settings/)
(`BaseSettings`), which reads from env vars or files and types the fields as
`SecretStr` directly. See the secrets style guide for where those values should
come from.

## Control Flow

- **Walrus operator** (`:=`) when it eliminates a repeated expression and
  remains readable.
- **Don't look before you leap.** Do the access and handle the miss, rather than
  checking for membership and then accessing again. Prefer `try/except` or `.get()`
  over `if x in y: use y[x]`: the latter does two lookups and obscures intent.
  Exception: when the "miss" is the *common* path, raising is expensive in CPython.
  If the exception fires on nearly every call, a pre-check may be faster.

## Async

- **Concurrent independent awaits.** When coroutines don't depend on each
  other's results, run them with `asyncio.gather` or `asyncio.TaskGroup`
  instead of sequential `await` calls.
- **Background tasks for periodic work.** TTL sweeps, cache eviction, and
  similar maintenance don't belong inline on the critical path; start them with
  `asyncio.create_task` at app startup.

## Performance

These are proactive design decisions, not micro-optimizations to apply after
the fact. See the `python-profiling` skill for measurement tools.

- **Construct expensive objects once.** Objects like parsed configs, compiled
  schemas, HTTP clients, and connection pools should be built at startup and
  injected as dependencies, not reconstructed per-request. Use the app
  framework's lifespan hook (e.g., FastAPI's `lifespan` parameter) to run
  expensive setup before serving traffic.
- **Cache pure function results** with `@functools.cache` / `@functools.lru_cache`
  (no expiry) or `cachetools.TTLCache` (time-bounded). Set explicit TTLs when
  the underlying data can change.
- **Parse once.** If a deserialized result is needed in two places (e.g., a
  debug log and actual processing), parse once and pass the result to both.

## Toolchain

- **[`uv`](https://docs.astral.sh/uv/)** for project management and running scripts
  (`uv run`, `uv add`)
- **[`ruff`](https://docs.astral.sh/ruff/)** for formatting and linting
- **[`mypy`](https://mypy.readthedocs.io/)** for static type checking;
  use strict settings unless the project has a different established baseline;
  add `plugins = ["pydantic.mypy"]` when pydantic is in use
- **[`pre-commit`](https://pre-commit.com/)** for pre-commit checks
- **[`pytest`](https://docs.pytest.org/)** for testing, with:
  - [`pytest-asyncio`](https://pytest-asyncio.readthedocs.io/) for async tests
  - [`pytest-xdist`](https://pytest-xdist.readthedocs.io/) for parallel execution
  - [`pytest-randomly`](https://github.com/pytest-dev/pytest-randomly) for random ordering
  - [`pytest-mock`](https://pytest-mock.readthedocs.io/) for mocking: always use the
    `mocker` fixture, never `unittest.mock` decorators
  - [`hypothesis`](https://hypothesis.readthedocs.io/) for property-based testing
    (rarely needed, but irreplaceable when you do)

### Ruff Configuration

Use `line-length = 120`. For `[tool.ruff.lint]`, start with this `select` set:

```toml
[tool.ruff.lint]
select = [
  "I",    # isort: import ordering
  "F",    # pyflakes: unused imports, undefined names
  "E",    # pycodestyle errors
  "W",    # pycodestyle warnings
  "PIE",  # flake8-pie: miscellaneous cleanups
  "PLC",  # pylint convention
  "PLE",  # pylint error
  "PLW",  # pylint warning
  "PTH",  # flake8-use-pathlib: enforce pathlib over os.path (matches style guide)
  "PGH",  # pygrep-hooks: blanket noqa, deprecated calls
  "RUF",  # ruff-specific rules
]
```

Common `ignore` entries with rationale:

```toml
ignore = [
  "E501",  # line length: formatter owns this
  "E741",  # ambiguous variable name: occasionally fine (e.g. l in math)
  "T201",  # print: allowed in CLIs and scripts
  "T203",  # pprint: same
]
```

Only add an ignore if you have a concrete reason; don't suppress speculatively.

## Preferred Libraries

- **[`pydantic`](https://docs.pydantic.dev/)** for serialization/deserialization and
  validated data models at system boundaries (not for internal data structures)
- **[`fastapi`](https://fastapi.tiangolo.com/)** as the web framework
- **[`typer`](https://typer.tiangolo.com/)** for CLIs
- **[`more-itertools`](https://more-itertools.readthedocs.io/)** for extended iteration utilities
- **[`cachetools`](https://cachetools.readthedocs.io/)** and
  **[`cachetools-async`](https://github.com/bharel/cachetools-async)** for caching

## References

- [Python standard library](https://docs.python.org/3/library/)
