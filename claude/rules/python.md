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
| `@dataclass(slots=True)` | Only when the instance's own fields must be reassigned |
| `NamedTuple` | Only when tuple unpacking is genuinely required (should be rare) |
| `TypedDict` | Smell: only when an existing API forces a bare dict shape |
| Plain `dict` | Truly dynamic keys or quick one-off mappings |

Avoid plain classes. Strongly prefer dataclasses; if you would have put logic in
`__init__`, use a `@classmethod` factory instead. Default to frozen+slotted.
Prefer Pydantic over `TypedDict` for any validated or serialized data;
reach for `TypedDict` only when you genuinely can't control the shape.

`frozen=True` blocks only rebinding the instance's own fields; it says nothing
about the field *values*. A frozen dataclass can still hold a list you append
to or a mutable object you mutate, and that's fine. Interior mutability of a
field is not a reason to drop `frozen`: keep the dataclass frozen and omit it
only when you genuinely need to reassign the instance's own fields.

Make Pydantic models frozen, mirroring the frozen-by-default dataclass rule:
set it through the `model_config` classvar with `ConfigDict`, not the older
`class Config` inner class.

```python
class Order(BaseModel):
    model_config = ConfigDict(frozen=True)
```

## Time and Durations

- **Represent time intervals as `timedelta`, not bare numbers.** Any value
  that *is* a duration (config options, sleep durations, timeouts, TTLs,
  retry backoffs) should be a `datetime.timedelta`, so the unit is explicit
  and can't be misread as seconds-vs-milliseconds at the call site.
  Reasonable exception: a value that never leaves the context it's produced
  in and is obviously an interval, such as subtracting two `time.monotonic()`
  calls in the same function to measure elapsed time.

## Strings

- **f-strings** for all string formatting, including logging calls. No `.format()` or `%`.
  (The conventional advice to use `%`-style in logging to defer interpolation is rarely
  a meaningful optimization in practice.)

## Docstrings

- **Never write module-level docstrings.** The module's name and contents
  already document it; a top-of-file docstring is noise that drifts out of
  date. (See the comments rule: capture the non-obvious *why*, never the
  obvious *what*.)
- **Write docstrings in Markdown by default.** Use Markdown formatting
  (backticks for identifiers, `-` lists, fenced code blocks) for any docstring
  worth writing. If the project has an established docstring convention
  (reStructuredText, Google, NumPy style), follow that instead.

## Module Privacy

Don't use `_` prefixes to signal private names. Control the public API
surface through `__init__.py` re-exports instead: export only what's
intentionally public and omit the rest. Type checkers, IDEs, and
`from module import *` all respect `__all__` and re-export boundaries,
so the constraint is enforced structurally without cluttering identifiers.

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
- **`match` statements should be total.** End every `match` with a final
  `case`. When some values legitimately need no handling, use an explicit
  `case _: ...` default. When the match is meant to be exhaustive over a
  known set (an enum, a union of types, a sealed hierarchy), close it with
  `case _ as unreachable: assert_never(unreachable)` so the type checker
  flags any unhandled variant at the unreachable branch, turning a missed
  case into a static error rather than a silent fall-through.
- **Unparenthesized multiple exception types are valid (Python 3.14+).**
  Per [PEP 758](https://peps.python.org/pep-0758/), `except A, B:` and
  `except* A, B:` are legal syntax, equivalent to `except (A, B):`. This is
  *not* the removed Python 2 `except A, B:` (catch `A`, bind to `B`). Brackets
  may be omitted only when there is no `as` clause; `except (A, B) as e:` still
  requires them.
- **Log exceptions with `repr(e)`, not `str(e)`.** Some exceptions have an
  empty `str()` (the message lives in the type or args), which turns into a
  blank log field; `repr(e)` always shows at least the exception type.
- **Never `assert` outside of tests.** `python -O` (and `PYTHONOPTIMIZE`)
  strips every `assert`, so an assertion guarding real runtime behavior
  silently vanishes in optimized runs. Raise an explicit exception instead
  (`TypeError` for a wrong type, `ValueError` for a bad value). `assert` is
  fine in test bodies and for `assert_never` exhaustiveness checks the type
  checker reads statically.

## Async

- **Concurrent independent awaits.** When coroutines don't depend on each
  other's results, run them with `asyncio.gather` or `asyncio.TaskGroup`
  instead of sequential `await` calls.
- **Background tasks for periodic work.** TTL sweeps, cache eviction, and
  similar maintenance don't belong inline on the critical path; start them with
  `asyncio.create_task` at app startup.
- **Bounded concurrency over large iterables.** `gather()` + semaphore and
  `as_completed()` both consume the input iterable upfront, which blows memory
  on large inputs. Use `asyncio.wait()` with
  `return_when=asyncio.FIRST_COMPLETED`, keeping a bounded set of pending tasks:
  fill to `limit`, await until one completes, yield it, refill. See [Limiting
  concurrency in Python asyncio](https://death.andgravity.com/limit-concurrency)
  for the full pattern and tradeoffs.
- **Don't hold an invariant across an `await` on shared state.** An `await` is a
  suspension point: while a coroutine is parked there, other tasks run and can
  mutate any shared place it reaches, so a value read or checked *before* the
  `await` may be stale or violated *after* it, even in single-threaded asyncio.
  Configuring a shared `ssl.SSLContext`'s ALPN protocols and then reading the
  negotiated protocol after `await open_connection(...)` is a race: a concurrent
  caller can reconfigure the context mid-negotiation. Hand each operation its own
  value instead (take a factory that produces a fresh object per use, or snapshot
  what you need before the `await`) rather than sharing a mutable place across the
  suspension. See the values-over-places rule.

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

## Type-level tests

When a guarantee lives in the type system (a generic bound, variance, an
overload set, a "this call must not type-check"), assert it with the type
checker, not just the runtime suite. This is how you regression-guard an
invariant that has *no runtime failure to catch* because the whole point was to
turn it into a static error.

Put the cases in a normal test module (so they live with the tests and run
through the same type-check pass) and drive two directions:

- **Positive:** `typing.assert_type(expr, T)` pins that `expr` has exactly type
  `T`. Use it for the invariants that are easy to break silently: what a generic
  solves to, what an overload returns, the element type of a container.
- **Negative:** write the code that *should* fail and mark it with a specific
  `# type: ignore[code]`. With mypy's `warn_unused_ignores = true` (part of
  `strict`), the ignore doubles as an assertion: if the line ever stops erroring,
  the now-unused ignore fails the build. That is the regression guard a deleted
  runtime check no longer provides.

Two things make this robust:

- **Match the exact error code, not a bare `# type: ignore`.** A bare ignore is
  satisfied by *any* error on the line, so an unrelated breakage still looks
  green. Run the checker once to see the real code (it is not always the obvious
  one: a bad argument to an *overloaded* call often reports `call-overload`,
  while the same argument to a single signature reports `arg-type`), then pin
  that code. Keep the rest of the line otherwise valid so it is the only error.
- **Guard the whole block behind `if TYPE_CHECKING:`.** mypy still checks the
  branch; the runtime never executes it, so there are no placeholder objects to
  construct or drive. `assert_type` is erased at runtime anyway, but the negative
  lines would otherwise run.
- **Write the `assert_type` target as a bare type, not a string.** A
  string-quoted target (`assert_type(x, "Extractor[RequestHead, int]")`) hides
  the type names inside a string literal, so ruff's unused-import pass doesn't
  see them as used and silently strips their imports on autofix, breaking the
  test only after the next lint run. A bare expression keeps the names live.

```python
from typing import TYPE_CHECKING, assert_type

if TYPE_CHECKING:
    assert_type(path_param("id", INT), Extractor[RequestHead, int])
    handle_stream(body(parse, schema=S), fn=fn)  # type: ignore[arg-type]
```

For asserting a checker's *exact* diagnostic output (message text, not just
"errors here"), a purpose-built harness like `pytest-mypy-plugins` exists, but it
is a heavy dependency; reach for it only when the `assert_type` + typed-ignore
pair genuinely can't express the invariant.

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

  See the `optimize-pytest` skill when a suite is slow or flaky: profiling with
  `--durations`/pytest-durations, fixture scope, removing sleeps, xdist
  distribution, pytest-randomly to surface isolation bugs before CI, and cutting
  collection/import/coverage startup cost.

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
