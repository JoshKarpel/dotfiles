---
name: optimize-rust
description: >
  Rust performance profiling and optimization: find where a Rust binary spends its
  time and prove a change made it faster. MUST be invoked when a Rust program is
  slow, a hot path needs finding, a benchmark regressed, or someone asks where the
  time goes. Covers benchmark harness choice (hyperfine vs criterion/divan, and why
  `#[bench]` is out), the `[profile.profiling]` + frame-pointers build, recording
  with `perf` and reading the result with samply plus a bundled report script,
  interpreting self vs inclusive time, and Rust-specific wins (rayon over a pure
  hot path, `build.rs` over runtime `LazyLock`, pricing a feature-flag constraint).
  Use for "why is this Rust code slow", "profile this binary", "flamegraph",
  "is this actually faster", "cargo bench", "hyperfine", "samply", "perf record",
  or when a release build is fast enough to compile but too slow to run.
---

# Optimizing Rust

## The Loop

1. **Measure a baseline** with hyperfine, through the real artifact. A profiler
   answers *where*; only a wall-clock benchmark answers *how much* and *is it noise*.
2. **Bound the win before chasing it.** Stub the suspect out entirely and measure
   the ceiling. If deleting the thing outright is a 4 ms win on a 900 ms run, no
   partial version of it is worth building.
3. **Locate the hotspot** by profiling (below), and check the unwind fraction
   before believing any inclusive number.
4. **Form a hypothesis and isolate one variable**, ideally with synthetic inputs
   that differ in exactly one dimension.
5. **Fix, then re-measure with the same harness.** A speedup that doesn't show up
   in hyperfine didn't happen.

## Measuring

### Harness choice

`#[bench]` / `test::Bencher` is **nightly-only**, so it's out on any stable-pinned
project. That leaves:

- **hyperfine over the built binary** for CLI/end-to-end work. Measures what a user
  actually waits on: process startup, parse, work, write. No dev-dependency, no
  compile cost. Default choice for a binary.
- **criterion or divan** as dev-dependencies for in-process, per-stage numbers.
  Reach for these when you need to attribute time *within* the program and are
  willing to pay the compile cost.

```bash
hyperfine --warmup 3 -N "target/release/mybin run input.txt"
```

- `-N` skips the intermediate shell, which matters for sub-second commands.
- `--warmup N` discards the first runs (page cache). Note this does *not* warm any
  in-process lazy state: each run is a fresh process, so `LazyLock`/`OnceLock`
  initialization is paid every single run. That is often exactly the thing you're
  measuring.
- `--parameter-list` sweeps fixtures; `--export-json` / `--export-markdown` to
  save a baseline for comparison.

### Noise discipline

**A borderline delta is noise until you raise the sample count.** A 20-run
comparison once showed a 880 → 934 ms regression that vanished entirely at 30 runs
(865 vs 860), after an optimization had already been started to "fix" it. Before
acting on a small delta, re-run with `-m 30` (or more) and see if it survives.

Compare `user` vs `system` time to attribute a win: a drop in `system` time points
at I/O or output size, a drop in `user` time at CPU work.

## Profiling

### Build setup

Give profiling its own Cargo profile. Don't add `debug = true` to `[profile.release]`
and make every shipped binary carry symbols nobody reads:

```toml
[profile.profiling]
inherits = "release"
debug = true
```

Frame pointers are a rustc codegen flag, not a Cargo profile key, so they go in
the environment at build time:

```bash
RUSTFLAGS="-Cforce-frame-pointers=yes" cargo build --profile profiling
```

### Record with perf, read with samply

Record with `perf` and use samply only as the reader. samply's own sampler copies a
**hardcoded 32 KB of user stack per sample** and unwinds that copy; deeply recursive
code (regex compilation is a common offender) blows past the window and every frame
above it is lost. There is no CLI flag to raise it. On one real workload this was
the difference between **21% and 99% of stacks unwinding completely**. `perf` walks
the frame-pointer chain in the kernel with no such window.

```bash
# Multiple iterations: one short run yields too few samples to say anything.
perf record --call-graph fp --freq 2000 --output target/profile/perf.data \
  -- bash -c 'for _ in $(seq 10); do target/profiling/mybin run input.txt >/dev/null; done'

samply import target/profile/perf.data --save-only --no-open -o target/profile/profile.json
```

`samply import` produces the same JSON samply itself writes, so `samply load
target/profile/profile.json` still opens the Firefox Profiler UI for a flamegraph
and timeline when a human wants to look.

If `perf` is unavailable, `samply record -- ./target/profiling/mybin ...` works and
is much simpler to set up. Just check the unwind fraction and distrust inclusive
time if it's low.

For kernel settings, WSL2 quirks, and `perf` installation, read
`references/platform-setup.md`.

### Read the profile

Don't read the JSON directly; it's large and dense. Use the bundled script, always
via `uv`:

```bash
uv run ${CLAUDE_SKILL_DIR}/scripts/profile_report.py target/profile/profile.json \
  --binary target/profiling/mybin --label "run input.txt"
```

`--binary` is **required for an imported `perf.data`**, because the profile's
"product" is whatever perf was told to run (the shell wrapping the loop), not your
binary. Run with `--help` for `--top` and `--stacks`.

Output is four ranked tables: self time by crate, self time by symbol (with
`file:line`), inclusive time, and hottest stacks. Threads that never executed the
binary (the looping shell and its other children) are dropped.

## Gotchas

These are the ways a Rust profile misleads. Most cost real time to discover.

- **Check the unwind fraction first.** The report's header says what share of stacks
  reached the frame their thread began at. Below ~95%, treat every inclusive number
  as a floor, not a measurement. The tell that something is wrong: a caller showing
  *less* inclusive time than its own callee.
- **`addr2line --inlines` is mandatory for optimized Rust.** Everything inlines into
  a handful of outer symbols, so a plain symbol-table reading reports little beyond
  `main`. The script does this; if you resolve addresses by hand, pass `--inlines`.
- **Never resolve a stripped system library with a debug-info tool.** `addr2line`
  against a stripped `libc.so.6` answers with the nearest preceding *exported*
  symbol rather than admitting it doesn't know. This once charged 8% of a run to
  `_dl_mcount_wrapper`, which was really a `memmove` variant. Use
  `nm --dynamic --defined-only --print-size` with size-bounded containment, so an
  address inside an unexported function stays an address. The script does this.
- **Inclusive time in a parallel program is dominated by thread scaffolding.** With
  rayon, the top inclusive rows are `thread_start`, `catch_unwind`, and the pool's
  closures at ~94%. That's structure, not a hotspot. Read self time instead.
- **Idle worker threads appear in the profile.** A rayon pool's `wait_until_cold` /
  `Sleep::sleep` / `condvar wait` stacks are workers with nothing to do, not work.
  Don't optimize them.
- **Kernel frames stay unresolved** unless `kptr_restrict` is relaxed; the script
  buckets them as `[kernel]` rather than emitting a row per raw address.
- **`samply import` does not regenerate the `--unstable-presymbolicate` sidecar**
  that `samply record` writes. A stale `profile.syms.json` from an unrelated earlier
  recording will silently name frames in a new one. Don't rely on that sidecar; the
  script reads symbols directly instead.
- **Don't write a performance claim you haven't measured**, especially into docs. A
  plausible one ("long runs amortize startup, so they gain less from parallelism")
  turned out to be exactly backwards when measured (they gained ~3.5x, short ones
  ~1.7x).

## Rust-Specific Wins

Things worth actively checking for, drawn from profiles rather than folklore.

- **Lazily-compiled machinery dominates short runs.** Syntax sets, regex engines,
  and other `LazyLock`/`OnceLock` state compile once per *process*, so for a CLI
  that exits quickly it can be nearly all of the runtime (91% in one case, against
  ~2% actually matching). The cost scales with the number of *distinct* things
  compiled, not with input size: prove this by holding input size fixed and varying
  only the variety.
- **Parallelize a hot path that is already pure.** If the work has no I/O and no
  shared mutable state, `par_iter().map(...).collect()` preserves order and is often
  a handful of lines for a ~3x win. Verify output is byte-identical, and check it
  still wins on 2 and 4 cores, not just yours. Wall-clock improves while total CPU
  goes *up*; that's the trade.
- **Compile-time-constant data belongs in `build.rs`**, not a runtime `LazyLock`.
  If a value is a pure function of files already known at build time (encoding,
  embedding, table generation), emit it to `OUT_DIR` in `build.rs` and pull it in
  with `include_str!(concat!(env!("OUT_DIR"), "/thing.rs"))`. Costs nothing at
  runtime. Commit the generated artifact if regenerating it needs network access
  that CI won't have.
- **Price a design constraint without adopting the change.** Swapping a Cargo
  feature (a pure-Rust regex engine for a C-backed one) measured a 9x win, which was
  then deliberately *declined* because the C dependency broke a cross-compile matrix.
  Back up `Cargo.toml`, measure, restore. Knowing what a constraint costs is worth
  having even when the answer is "keep the constraint".
- **Micro-optimizing your own code is usually the wrong target.** In a dependency-heavy
  binary, the crate's own symbols were 0.05-1.8% of the total. Check the by-crate
  table before touching anything.
- **Throwaway measurements go in `examples/`.** `cargo run --release --example probe`
  gives a real optimized binary without touching `tests/` or leaving dead code.
  Delete it when done.

## References

- [samply](https://github.com/mstange/samply)
- [hyperfine](https://github.com/sharkdp/hyperfine)
- [The Rust Performance Book](https://nnethercote.github.io/perf-book/)
- [Cargo profiles](https://doc.rust-lang.org/cargo/reference/profiles.html)
