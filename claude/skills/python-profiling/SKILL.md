---
name: python-profiling
description: Python performance profiling and optimization. Use when investigating CPU hotspots, memory usage, I/O slowness, async event loop blocking, or when optimizing slow Python code. Covers tools (cProfile, line_profiler, austin/speedscope, scalene), flamegraph generation, and common optimization patterns (concurrent awaits, regex combining, recursive memoization, eliminating duplicate work, moving blocking I/O off the event loop).
---

# Python Performance Profiling

## The Profiling Loop

1. **Pick a profiler** based on what you're investigating: cProfile or austin for CPU hotspots, scalene when you also need memory, line_profiler when you've already found the hot function and want line-level detail, `PYTHONASYNCIODEBUG=1` for event loop blocking.
2. **Profile** a realistic workload — not a toy input if the real bottleneck only appears at scale.
3. **Read the output** (using the helper scripts if necessary, e.g., `profile_speedscope.py`, `profile_scalene.py`) to get a ranked summary. Focus on self-time (where CPU actually burns), not just inclusive time.
4. **Pick a few things** to fix — don't try to fix everything at once. Start with the highest self-time hotspot that looks addressable.
5. **Fix and measure again** — profile with the same workload to confirm the improvement. Speedups that don't show up in the profiler didn't happen. That said, it's fine to rework something into the clearly correct shape even if it doesn't move the benchmark — every nanosecond counts, even when something else is dominating. Focus on the biggest things, but not at the total expense of the small ones.
6. **Iterate** until the performance is acceptable or the remaining hotspots are outside your control (C extensions, network, OS).

---

## Tools

### cProfile (built-in, call-level CPU)

```bash
python -m cProfile -o profile.out myscript.py
# sort by cumulative time:
python -c "import pstats; p = pstats.Stats('profile.out'); p.sort_stats('cumulative'); p.print_stats(30)"
```

For other ways to visualize `.prof`/`.out` files (GUI browsers, SnakeViz, gprof2dot, etc.), see the [Python profiling docs](https://docs.python.org/3/library/profile.html) and check what's available in the environment.

### line_profiler (line-level CPU)

```bash
uv add --dev line-profiler
```

Decorate functions you want to drill into with `@profile` (no import needed when running via kernprof), then:

```bash
kernprof -l -v myscript.py
# -l: line-level profiling, -v: print results immediately
# results also saved to myscript.py.lprof; view later with:
python -m line_profiler myscript.py.lprof
```

### austin + speedscope (sampling CPU → flamegraph)

austin is a statistical/sampling profiler that attaches to a running Python process or launches one. It produces output that can be converted to speedscope format for interactive flamegraphs. See the [austin README](https://github.com/P403n1x87/austin) for full details; run `austin --help` to see all flags.

```bash
uv add --dev austin-python  # installs austin-python converter tools
# also need austin itself: brew install austin / apt install austin / cargo install austin
```

**Profile a script and produce a flamegraph:**

The pipeline depends on the austin version — check first:

```bash
austin --version
```

**Austin >= 4**: writes binary MOJO format by default, requires a two-step conversion:

```bash
austin -i 100 -o austin.mojo python myscript.py
uvx --from austin-python mojo2austin austin.mojo austin.collapsed
uvx --from austin-python austin2speedscope austin.collapsed austin.json
```

**Austin < 4**: writes collapsed stack text directly, one step:

```bash
austin -i 100 -o austin.collapsed python myscript.py
uvx --from austin-python austin2speedscope austin.collapsed austin.json
```

Then open `austin.json` in speedscope: go to https://www.speedscope.app and load the file, or run `npx speedscope austin.json`.

Key austin flags:
- `-i <microseconds>`: sampling interval (default 100; lower = more detail, more overhead)
- `-C`: include child processes
- `-t`: terminate austin when the target exits (usually what you want for scripts)
- `-p <pid>`: attach to running process instead of launching one

**Attaching to a running process** (useful for servers/services):

```bash
austin -p $(pgrep -f myserver.py) -x 30 -o austin.out
# then apply the version-appropriate conversion pipeline above
```

### scalene (CPU + memory + GPU, line-level)

scalene is a high-detail profiler that simultaneously tracks CPU time, memory allocation, and GPU (if available) at the line level. Good when you need both CPU and memory in one pass.

```bash
uv add --dev scalene
scalene --json --outfile profile.json myscript.py
```

Scalene distinguishes Python time vs. native/C time per line — useful for finding where numpy/pandas/etc. are spending time.

---

## Analyzing Profile Output Programmatically

Speedscope JSON and scalene JSON are large and dense — don't try to read them directly. Use the helper scripts in `scripts/` to extract actionable summaries. Always invoke them with `uv run`.

### Speedscope summary (`scripts/profile_speedscope.py`)

Parses a speedscope JSON and reports self-time and inclusive-time per function, filtered to user code by default (stdlib/frozen frames hidden unless `--all`).

```bash
uv run scripts/profile_speedscope.py austin.json
uv run scripts/profile_speedscope.py austin.json --all        # include stdlib
uv run scripts/profile_speedscope.py austin.json --top 20     # more entries
uv run scripts/profile_speedscope.py austin.json --chains     # show top call chains
```

Output: ranked tables of self-time (where CPU actually burns) and inclusive-time (what called the hot code), with file:line references for easy navigation.

### Scalene summary (`scripts/profile_scalene.py`)

Parses a scalene JSON and reports CPU breakdown (Python vs native/C) and memory per function and per line.

```bash
uv run scripts/profile_scalene.py scalene-profile.json
uv run scripts/profile_scalene.py scalene-profile.json --top 20
uv run scripts/profile_scalene.py scalene-profile.json --memory  # sort by memory
```

Output: function-level and line-level tables with `P`/`C` bars (Python vs native CPU %), average memory footprint, and async await statistics if present.

---

## Async / Event Loop Profiling

### Detecting hidden blocking I/O

Blocking file I/O inside async code is a major source of event loop stalls, especially in cloud environments with network-backed volumes (e.g., NFS, EFS, GCS FUSE) where filesystem calls that are instant locally can take tens or hundreds of milliseconds. This is often invisible in local dev and only surfaces in production.

This matters most in **servers**, where blocking the event loop delays all other requests (responsiveness + throughput both suffer). In **scripts**, the event loop usually isn't handling concurrent requests, so blocking I/O hurts throughput but not responsiveness — it's still worth fixing, but the priority is different.

**Detection options:**

- Set `PYTHONASYNCIODEBUG=1` in the environment before running — logs a warning for any coroutine that blocks the loop for more than 100ms. Note: this makes asyncio significantly slower, so only use it for debugging sessions, not in production or benchmarks. Equivalent in code: `asyncio.get_event_loop().set_debug(True)`.

- `aiomonitor` or `aiodebug` for runtime loop inspection
- `py-spy` with `--threads` can show what threads are blocked on

**Fix: move blocking work off the event loop with `asyncio.to_thread`:**

```python
import asyncio

# Before: blocks the event loop
def read_file(path):
    with open(path) as f:
        return f.read()

# After: runs in a thread pool, event loop stays free
async def read_file_async(path):
    return await asyncio.to_thread(read_file, path)
```

`asyncio.to_thread` helps when the blocking work can drop the GIL internally (file I/O, network calls via C extensions, etc.). It won't improve raw throughput if the work is CPU-bound Python, but it keeps the event loop responsive — which is the main win in servers. In scripts, prefer fixing throughput directly (concurrent awaits, batching) rather than reaching for `asyncio.to_thread`.

---

## Common Optimization Patterns

### Awaits in a loop → concurrent execution

Sequential awaits that are independent are a frequent bottleneck. Replace with `asyncio.gather` or `asyncio.TaskGroup`:

```python
# Slow: sequential, each waits for the previous
results = []
for item in items:
    results.append(await fetch(item))

# Fast: all launched concurrently
results = await asyncio.gather(*[fetch(item) for item in items])

# Or with TaskGroup (Python 3.11+, better error handling):
async with asyncio.TaskGroup() as tg:
    tasks = [tg.create_task(fetch(item)) for item in items]
results = [t.result() for t in tasks]
```

Look for any `await` inside a `for` loop where iterations don't depend on each other.

### Combining regex patterns

Multiple `re.sub` or `re.search` calls with the same replacement can often be combined with `|`:

```python
# Before
s = re.sub(r'foo', '', s)
s = re.sub(r'bar', '', s)
s = re.sub(r'baz', '', s)

# After (same replacement)
s = re.sub(r'foo|bar|baz', '', s)

# When replacements differ, use a dict + function:
replacements = {'foo': 'FOO', 'bar': 'BAR', 'baz': 'BAZ'}
pattern = re.compile('|'.join(re.escape(k) for k in replacements))
s = pattern.sub(lambda m: replacements[m.group(0)], s)
```

### Recursive functions: hoist repeated work

Look for calculations inside a recursive function that produce the same result at every level, or that duplicate work already done by the caller. Move them outside the recursion or pass them down as parameters:

```python
# Before: recomputes config/constants at every level
def walk(node, depth=0):
    config = load_config()       # same every call!
    threshold = compute_threshold(node.root)  # same every call!
    ...
    for child in node.children:
        walk(child, depth + 1)

# After: public wrapper does shared work once, then calls the real recursion
def walk(node):
    config = load_config()
    threshold = compute_threshold(node.root)
    _walk(node, depth=0, config=config, threshold=threshold)

def _walk(node, depth, config, threshold):
    ...
    for child in node.children:
        _walk(child, depth + 1, config, threshold)
```

Also look for work that a parent already did that a child re-does (e.g., re-parsing a value that was already parsed one level up).

### Eliminate unnecessary or duplicated work

- **Re-parsing HTTP responses**: parse once, pass the parsed object. Don't call `response.json()` or `response.text` multiple times (some HTTP clients re-decode on each access).
- **Look before you leap**: `if x in y and y[x] is not None` does two lookups; replace with `if y.get(x) is not None` or just `if y.get(x)`. More generally, avoid checking for membership and then immediately accessing — do the access once and handle the miss.
- **Repeated expensive calls with the same args**: consider `functools.lru_cache` or `functools.cache` for pure functions.
- **Reinitializing objects that don't change per-request**: some objects are expensive to construct but are constructed fresh on every request. Common culprits: `pydantic-settings` `BaseSettings` subclasses (reads env vars, validates, coerces types on every instantiation), HTTP clients, database connection pools, compiled regex patterns. The preferred fix is **manual dependency injection** — functions that need `Settings` (or any expensive object) should take it as an argument, and the caller is responsible for passing a single long-lived instance. This bubbles construction up to application startup (e.g., a FastAPI lifespan), where it naturally happens once. If refactoring to DI isn't practical, `@cache` on a no-arg factory is a reasonable fallback:

```python
from functools import cache
from myapp.config import Settings

@cache
def get_settings() -> Settings:
    return Settings()
```

---

## Fixes

<!-- Document observed failures and their fixes here as they arise -->
