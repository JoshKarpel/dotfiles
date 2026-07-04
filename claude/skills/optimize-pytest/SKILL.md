---
name: optimize-pytest
description: >
  Make a pytest suite faster and more trustworthy. MUST be invoked when a pytest
  run is slow, CI test time needs cutting, a suite should be parallelized, or
  tests are flaky/order-dependent. Covers measuring with --durations and
  pytest-durations, diagnosing fixture-scope waste (make read-only, then widen),
  replacing time.sleep with deterministic synchronization, parallelizing with
  pytest-xdist (-n, --dist worksteal/loadscope/loadgroup), hardening isolation
  with pytest-randomly so flakiness surfaces before CI, and cutting startup cost
  (collection, imports, coverage backend, testpaths, running fewer tests).
when_to_use: >
  Use for "tests take too long", "speed up CI", "run tests in parallel",
  "why is this fixture slow", "tests pass alone but fail together", "flaky
  tests", "sleep in a test", "timing-dependent test", "randomize test order",
  "xdist", "worksteal", "pytest-asyncio event loop scope", or when a green suite
  needs to run under parallelism/randomization to prove it is actually isolated.
---

# Optimizing pytest Test Suites

Work in this order: **measure, fix fixtures, remove sleeps, harden isolation,
parallelize**. Parallelizing an un-isolated suite just converts slowness into
flakiness, so prove isolation (randomly) *before* leaning on xdist for speed.

For profiling the code *under* a slow test (CPU/IO hotspots inside the
production code path), use the `python-profiling` skill instead. This skill is
about the suite's own overhead: fixtures, scope, ordering, distribution,
collection, and startup.

## 1. Measure: where does the time go?

Two complementary tools. Enable both; they answer different questions.

**Built-in `--durations`** lists the N slowest *individual* items, split into
setup / call / teardown:

```bash
pytest --durations=15 --durations-min=0.05
```

- `setup` lines are fixture cost; `call` lines are the test body. A slow
  `setup` line is the single most common lead: it points straight at an
  expensive fixture.
- `--durations=0` shows everything; `--durations-min=N` (seconds) drops noise.
- Reads bottom-up in the report; the slowest is last.

**pytest-durations** (`pip install pytest-durations`) auto-registers and adds an
*aggregated* report grouped by test/fixture, with total + median + count. This
is what reveals "a 0.2s fixture that runs 600 times = 2 minutes", which the
per-item view hides:

```bash
pytest --pytest-durations-group-by=function
```

- `--pytest-durations=N` limits rows; `--pytest-durations=0` disables its report.
- `--pytest-durations-group-by={legacy,module,class,function,none}`: group by
  `function` to collapse parametrized cases and see a fixture's whole-suite cost.
- The **num** column times **med** is the lever. A fixture with a high count is a
  scope-widening candidate; a fixture with num=1 but a huge total is an intrinsic
  cost to optimize or mock.

Neither view captures time spent *before the first test runs*: collection and
imports. That is a separate axis, measured separately (see "Startup cost" below).
If the whole run feels slow but per-test durations look fine, the cost is there.

## 2. Fix fixtures: scope is the biggest win

First, setup has to *be* a fixture before any of this applies. Expensive
construction done inline in each test body (or copy-pasted into a `setup`
helper every test calls) runs once per test and is invisible to pytest's scope
machinery: you can't widen what isn't a fixture. The first move is to extract
that repeated setup into a fixture. That alone removes the duplication and, more
importantly, exposes the `scope=` knob the rest of this section turns. Extract
first, then widen.

A `scope="function"` fixture runs once per test. Widening it to `module`,
`package`, or `session` runs the expensive setup once for many tests. In the
measured example, a 0.2s function-scoped fixture used by 6 tests cost 1.2s of
setup; the equivalent module-scoped fixture cost 0.5s once.

The move is usually not "is this safe to widen?" but "make it read-only, *then*
widen." A fixture is safe to share across tests exactly when nothing a test does
can leak into the next test that shares it:

- **A fixture that yields an immutable value or a read-only resource is already
  safe** to widen to `module`/`package`/`session`. This is the values-over-places
  rule: share values freely; be wary of sharing *places*.
- **A fixture whose result tests mutate** (a shared list, a DB row, a temp dir, a
  global) is not: widening it makes tests bleed state into each other, which §4
  is designed to catch. Don't just leave it function-scoped. First convert it to
  read-only, then widen:
  - Return a value, or a frozen/immutable copy, instead of a live mutable place.
  - Split the fixture: widen the *expensive construction* to session scope and
    hand each test a cheap, isolated view (session-scoped DB engine plus a
    function-scoped transaction rolled back in teardown; session-scoped template
    dir plus a per-test copy).
  - Push any per-test mutation into the test itself, so the shared fixture stays
    pristine.

The payoff compounds: a read-only fixture is not only cheaper to widen but also
safe to share across xdist workers (§5), where a mutable one races.

**Deduplicate across modules with `conftest.py`.** A fixture copy-pasted into
several test files, or a `module`-scoped fixture that rebuilds the same expensive
thing once per file, is doing the work N times. Hoist one definition into a
`conftest.py` and give it `session` (or `package`) scope: pytest builds it once
and shares it with every test below that directory. Two rules govern this:

- **Location controls visibility; scope controls lifetime.** The conftest's
  directory decides which tests can *see* the fixture; the `scope=` decides how
  often it's *built*. Put the conftest at the shallowest directory whose tests
  all need the fixture (a package-level `tests/conftest.py`, or a subdir conftest
  for a narrower group), so the sharing is as wide as the fixture is safe.
- **Keep import-time work out of conftest.** Fixture *bodies* are lazy (they run
  only when a test requests them), so defining them costs nothing at collection.
  But top-level code in a widely-visible `conftest.py` (heavy imports, module-level
  setup) runs on *every* collection and slows startup (see "Startup cost").

Only session-shareable (read-only) fixtures belong at session scope here; the
read-only conversion above is the prerequisite.

**Async fixtures need a matching event loop scope (pytest-asyncio).** By default
each test and each function-scoped async fixture runs in its *own* event loop,
created and torn down per test. A `session`/`module`-scoped *async* fixture (a
shared connection pool, an `AsyncClient`) cannot span tests unless the loop spans
them too: objects bound to a closed loop break. These are two independent knobs:

- `scope=` on the fixture controls how often it's *built* (as above).
- `loop_scope=` controls *which event loop* runs it. Set both to the same scope,
  or the wider-scoped fixture is rebuilt (or errors) as the loop is recreated.

Set the default once in config so async fixtures share a loop by default:

```toml
[tool.pytest.ini_options]
asyncio_default_fixture_loop_scope = "session"  # or "module"/"package"
asyncio_default_test_loop_scope = "session"     # loop that runs the tests
```

Override per item with `@pytest_asyncio.fixture(loop_scope="session")` and
`@pytest.mark.asyncio(loop_scope="session")`. Leaving the fixture-loop default
unset is worth avoiding: it forces a fresh loop per test and older versions warn.

Same tradeoff as any widening, sharper here: a shared loop trades isolation for
speed. A pending task or half-closed transport left on the loop leaks into the
next test, which is exactly what §4 surfaces. Widen the loop only as far as the
async resources living on it are safe to share.

Other fixture wins: replace real I/O with fakes/in-memory doubles at the
boundary; move one-time global setup to session scope; prefer building a value
and returning it over yielding a mutable place.

## 3. Remove sleeps: deterministic is faster *and* stabler

`time.sleep` (and `asyncio.sleep`) in a test to "wait for" a background thread,
a retry, a debounce, a subprocess, or a timeout is the worst of both worlds: any
fixed duration is either too short (racy: flakes under load, and worse under
xdist contention) or too long (wasted wall-clock on every run). Sleeps show up as
slow `call` lines in §1 and as intermittent failures in §4; removing them usually
fixes both at once.

Replace the sleep with synchronization on the *actual* signal:

- Wait on the real primitive the code exposes: join the thread, await the
  future/task, `Event.wait()`, block on a queue/condition variable, read the
  channel, or `subprocess.wait()`. The test proceeds the instant the awaited
  state is reached and never a moment early.
- When only an observable *effect* is available (a file appears, a row commits),
  poll that condition on a tight loop with a generous *timeout ceiling*, not a
  fixed delay. The ceiling only bounds the failure case; the happy path returns
  immediately.
- **Control time instead of spending it.** For code that sleeps, schedules, or
  expires on a clock, inject a fake/controllable clock (or `freezegun` /
  `time-machine` / an event-loop time control) and advance it deterministically.
  The test asserts the timeout behavior in microseconds with zero flakiness.

A suite with no wall-clock waits is both faster and more deterministic, which is
exactly what makes §4 (randomly) and §5 (xdist) trustworthy rather than a new
source of flakes.

## 4. Harden isolation: pytest-randomly

`pip install pytest-randomly` auto-registers and, every run:

- reorders test **modules, classes, and tests**, and
- reseeds `random`, `os`, and (if present) `faker`/`numpy` **before each test**,

so hidden order-dependence and shared-state leaks fail *fast and locally*
instead of intermittently in CI. It prints the seed each run:

```text
Using --randomly-seed=1234567890
```

Reproduce a failure with the printed value or the sentinel `last`:

```bash
pytest --randomly-seed=last        # replay the previous run's order
pytest --randomly-seed=1234567890  # replay a specific reported seed
pytest -p no:randomly              # disable entirely (also isolates a bisect)
```

A test that passes alone but fails under a reordering seed is depending on
execution order or leaked state. Fix the test (or the widened fixture from §2);
don't pin the seed. This is exactly the coupling that xdist would otherwise turn
into nondeterministic CI failures, which is why randomly comes *before* xdist.

## 5. Parallelize: pytest-xdist

`pip install pytest-xdist`. `-n` sets worker count:

```bash
pytest -n auto        # physical cores
pytest -n logical     # logical cores (needs psutil)
pytest -n 4           # explicit
pytest -n 0           # disable (run in-process)
```

Workers are **separate processes**. Two consequences dominate everything else:

- **`session`/`module` fixtures run once *per worker*, not once total.** A
  session-scoped fixture on 8 workers is constructed 8 times. Very expensive
  session setup can make `-n auto` *slower*, not faster.
- **Shared external resources collide.** A session DB, temp path, bound port, or
  cache shared across workers races. Namespace per worker using the built-in
  `worker_id` fixture (`"gw0"`, `"gw1"`, ..., or `"master"` when not
  distributed), or the `PYTEST_XDIST_WORKER` env var, to give each worker its
  own DB name/schema/dir/port.

### `--dist` mode: how items map to workers

| mode | behavior | use when |
|---|---|---|
| `load` (default for `-n`) | any pending test to any free worker | isolation-clean suites |
| `worksteal` | split up front, idle workers steal from busy | recommended default; rebalances |
| `loadscope` | group by module/class, group to a worker | fixtures rebuilt per worker under `load` |
| `loadfile` | group by file to one worker | loadscope, at file granularity |
| `loadgroup` | `xdist_group`-marked tests share a worker | a few tests touch a serial resource |
| `each` | send every test to *every* worker | multi-environment/tox matrix, not speed |

```bash
pytest -n auto --dist worksteal
```

Reach for `worksteal` first: it keeps `load`-style balancing but rebalances when
a worker empties, so uneven test durations don't leave cores idle. Move to
`loadscope`/`loadfile` only when profiling (§1) shows a module/class fixture
being rebuilt across many workers under `load`; grouping trades some balancing
for far fewer fixture setups. Use `loadgroup` when a handful of tests touch a
resource that cannot be parallelized, marking just those with
`@pytest.mark.xdist_group(...)` so the rest still spread out.

pytest-randomly and xdist compose: randomly syncs its seed across workers, so a
parallel run is still reproducible and *still* exercises reordering. Keep both
on in CI. The one time to drop them is bisecting a failure, where `-p no:randomly`
plus `-n0` gives a deterministic in-process baseline.

## Startup cost: collection, imports, coverage

Everything above targets test *runtime*. A second, independent axis is the time
before and around the tests. It is paid on *every* invocation, including running
a single test, so it dominates fast local iteration. Measure it on its own:

```bash
pytest --collect-only          # collection time in isolation
python -X importtime -m pytest  # per-module import cost, slowest last
```

Rule of thumb: collection should be roughly 1s per 1000 tests (2-3s for large
codebases). Slower than that is a signal, usually one of:

- **Discovery scanning too much.** Point pytest at the tests, not the repo root:
  `testpaths = ["tests"]` (plus `norecursedirs`) in config. Scanning source and
  doctests means importing the whole codebase just to collect.
- **Heavy imports pulled in at collection.** `-X importtime` names the offenders
  (pandas, torch, django, a tracing agent). Move an import only some tests need
  into those tests, and drop libraries the tests don't use at all.
- **Expensive `conftest.py`.** `pytest --collect-only --noconftest`; if that is
  much faster, top-level conftest code (imports, fixtures defined at import time)
  is the cost.
- **Unused builtin plugins.** Minor, but free: `-p no:pastebin -p no:nose
  -p no:doctest`. `pytest --trace-config` lists what is active.

Two more, mostly for CI:

- **Coverage is a large hidden tax.** On Python 3.12+ with coverage.py 7.4+, set
  `COVERAGE_CORE=sysmon` to use `sys.monitoring` (PEP 669) instead of trace
  callbacks. Verify it took effect; older coverage silently ignores it.
- **Skip bytecode writes** in ephemeral CI containers: `PYTHONDONTWRITEBYTECODE=1`.

## Run fewer tests

The fastest test is the one you skip. Orthogonal to making each test faster:

- **Local iteration:** `pytest --lf`/`--last-failed` reruns only the previous
  failures; `--ff`/`--failed-first` runs them first, then the rest.
- **CI change-based selection:** `pytest-testmon` tracks which tests cover which
  lines and runs only those a change affects. Effective, but the dependency DB
  can drift; run the full suite periodically as the source of truth.
- **CI sharding by timing:** `pytest-split` divides the suite into equal-duration
  shards from recorded timings, one per parallel CI job, complementing xdist's
  within-job parallelism.
- **Quarantine known-slow tests** with a `@pytest.mark.slow` marker (or
  `pytest-skip-slow`): skip locally, run in the full/nightly CI job.

Guardrails that make the above safe by turning accidental slowness into a loud
failure: `pytest-socket` (`--disable-socket`) fails tests that touch the network;
`pyfakefs` swaps in an in-memory filesystem so tests never hit real disk.

## Quick reference

```bash
# 1. profile
pytest --durations=15 --durations-min=0.05 --pytest-durations-group-by=function
# 2. edit fixtures: make read-only, then widen scope
# 3. edit tests: replace time.sleep with synchronization on the real signal
# 4. prove isolation
pytest -p randomly          # note the reported seed
pytest --randomly-seed=last # replay any failure
# 5. parallelize
pytest -n auto --dist worksteal

# startup axis (paid every run): profile and trim
pytest --collect-only              # want ~1s per 1000 tests
python -X importtime -m pytest     # find heavy imports
# CI env: COVERAGE_CORE=sysmon (py3.12+), PYTHONDONTWRITEBYTECODE=1
```

## Gotchas

- **A fast per-item `--durations` can still hide the real cost.** 600 tests each
  paying 0.2s of the same fixture never shows a slow line; only pytest-durations'
  aggregated total does. Always run both.
- **Widening fixture scope silently breaks isolation.** The suite may stay green
  until reordering or parallelism perturbs it. Do §4 after any scope change.
- **A `time.sleep` in a test is a bug, not a wait.** It's either racy or wasteful,
  and it gets worse under xdist. Synchronize on the real signal or control a fake
  clock instead (§3).
- **`-n auto` can be slower** when session-scoped setup dominates: it now runs
  per-worker. Check wall time; sometimes fewer workers or `-n0` wins.
- **"Passes alone, fails together" means shared state**, not a pytest bug. Under
  xdist it means a resource shared across processes (DB/file/port); namespace it
  by `worker_id`. Under randomly alone it means order/leak within one process.
- **Don't pin the randomly seed to make CI green.** That hides the coupling
  instead of fixing it. Pin only to *reproduce* while debugging.
- **`each` is not a speed mode.** It multiplies work across workers; it's for
  running the same tests in multiple environments.
- **Coverage instrumentation is a big hidden tax**, easy to blame on the tests.
  Compare a run with and without `--cov`; on Python 3.12+ reach for
  `COVERAGE_CORE=sysmon` before optimizing anything else.
- **Plugin disable names** are the entry-point names, which differ from the PyPI
  package names: `-p no:randomly`, `-p no:pytest-durations`, `-p no:xdist`.

## References

- [awesome-pytest-speedup](https://github.com/zupo/awesome-pytest-speedup): a
  curated list of speedup techniques and plugins; check it before hand-rolling.
- [Making PyPI's test suite 81% faster](https://blog.trailofbits.com/2025/05/01/making-pypis-test-suite-81-faster/):
  worked example of xdist + `COVERAGE_CORE=sysmon` + `testpaths` + import trimming,
  with before/after timings for each.
- [pytest-asyncio: change the default event loop scope](https://pytest-asyncio.readthedocs.io/en/stable/how-to-guides/change_default_fixture_loop.html):
  the `asyncio_default_fixture_loop_scope` config and `loop_scope=` overrides.
