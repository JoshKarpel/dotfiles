# Testing

One of the payoffs of functional-core/imperative-shell, parse-don't-validate,
and dependency injection is that testing becomes easy: pure functions take data
in and return data out, so tests are plain assertions; and dependencies are
just arguments, so tests pass in whatever they need without patching.

- **Test the functional core directly, without mocks.** If you find yourself
  mocking to test a piece of logic, the logic is probably entangled with I/O.
  Extract it.
- **Prefer real objects via dependency injection over patching.** Pass a
  different argument in tests rather than monkeypatching globals or module
  internals.
- **When patching is unavoidable, patch where the name is looked up, not
  where it's defined.** A shim module that re-imports a third-party function
  binds its own name to it at import time; patching the shim leaves call
  sites that import directly from the third-party module untouched. Patch
  the module that actually resolves the name at runtime.
- **One behavior per test; arrange/act/assert; descriptive names.** A test
  name should state the behavior under test, not the function name. If a test
  covers multiple behaviors, it can only fail at one of them: split it.
- **Use non-default, distinct test values.** Avoid type-default values (`0`,
  `""`, first enum entry): a broken function may accidentally produce the
  default, making the test pass despite the bug. When a function takes multiple
  inputs, use a *different* value for each so argument mix-ups and aliasing
  bugs surface.
- **Parametrize over copy-paste.** When the same logic is exercised with
  different inputs, use the testing library's parametrization facility.
  Duplicated test bodies are as much of a maintenance burden as duplicated
  production code.
- **Property-based testing when the input space is large.** Generating many
  cases finds edge cases that example-based tests miss. Prefer it when
  invariants are clearer than specific examples.
- **Test at the boundary the parser establishes.** Concentrate edge-case tests
  at the point where external input is parsed into internal types. Once data is
  internal, trust the types: don't re-test the parser in every downstream unit.
- **Suspect the check on a pass as well as a failure.** A probe can quietly
  measure the platform's own behavior instead of the thing under test: a browser
  restoring scroll position, a same-document navigation that never re-runs the
  script, a default that masks the branch you meant to exercise. A pass is no
  safer than a failure: a probe asking whether a permission allows a shell
  command teaches nothing if the subject satisfies the request another way and
  never attempts that command. Confirm the probe reached the path you think it
  did before concluding anything from either outcome.
- **Prove a new test can fail.** A test that passes on its first run may be
  incapable of failing. Break the code deliberately, or run the test against a
  knowingly-broken copy, and confirm it fails before trusting it. This matters
  most where the obvious signal is constant: a script that always exits 0 has to
  assert a side effect instead, and an assertion on a side effect is easy to
  write in a form that holds either way. Undo the break with the inverse edit,
  or work on a copy: `git checkout --`/`git restore` reverts the *whole file* to
  HEAD, so it discards every other uncommitted change in it, which during a
  feature is most of the session's work. Restoring from a backup taken earlier
  has the same failure in slower motion, since the backup predates whatever you
  fixed in between.
- **Break exactly the mechanism under test.** A break that disables more than that
  mechanism (inverting a parameter that feeds other paths too, or reverting to an
  approximation of the old code) makes the test fail for some other reason, which
  proves nothing about the claim it makes. Make the smallest break that removes
  only that mechanism, check that the failure names it, and when reverting to old
  behavior, reproduce the old code faithfully.
- **A green run is not a fixed race.** For a failure that was already
  intermittent, one pass is the expected outcome even with no fix at all, so it
  is not evidence. Before crediting a fix, check that its mechanism could
  actually produce the effect (does the hook run before or after the teardown it
  is supposed to observe?), then get a second independent signal by re-running.
  A fix you can't explain mechanically is a coincidence you haven't caught yet.
- **Exclude a platform-only branch per platform, not everywhere.** When a
  coverage gate fails on a branch that only runs on another platform, a
  blanket `# pragma: no cover` stops measuring it everywhere, so the gate goes
  quiet if that path dies. Exclude it only where it can't run instead:
  coverage.py expands environment variables in its config, so an
  `exclude_also` entry of `pragma: skip-on-${PLATFORM}`, with the variable set
  per CI job, does it without a plugin. Don't name the pragma `no cover-…`:
  the default exclusion matches that prefix on every platform. The branch is
  only measured if the gate also runs where it executes; with single-platform
  CI, a per-platform pragma is a blanket one under another name. Where CI
  already runs a platform matrix, gating on the combined data
  (`coverage combine`, with `[paths]` mapping the source roots) needs no
  pragma at all. Building the other platform's shape locally (deleting the
  attribute the code probes for, constructing the other event loop directly)
  to test it for real on every platform is an option where it's cheap, not a
  prerequisite.
- **Coverage is a floor, not a ceiling.** 100% line and branch coverage means
  every line ran, not that anything pins its behavior: a mutation that flips an
  `and` to an `or` can survive a fully-covering test that never varies the
  second operand. Where the logic is subtle and the project has a mutation
  testing setup, run it over new code and kill the survivors. To judge whether a
  refactor weakened the suite, diff the survivor *sets* against a worktree at
  the pre-change commit, not the survivor counts, which hide a new survivor
  behind a newly-killed one.
- **Substring assertions match the whole artifact.** Generated output that embeds
  a script's own source will contain every selector that script mentions, and a
  negative assertion (`!output.contains("x")`) is satisfied by your own comment
  explaining why `x` is absent. Assert against the parsed element, or strip
  comments and embedded sources first.
- **A corpus sweep discovers; fixtures verify.** Running against real production
  data is how you find shapes you didn't anticipate. Once found, a shape becomes a
  committed fixture with a real assertion. "Nothing panicked across 300 files" is
  slow and proves almost nothing as a standing test.
- **No `sleep` to synchronize concurrent tests.** Sleeping to wait for a
  background operation is both slow and flaky: any fixed duration is either too
  short (racy under load) or too long (wasted wall-clock). Synchronize on the
  actual signal instead, with whatever the concurrency model offers, an event,
  a queue, a condition variable, a future or promise, a channel, or joining the
  task directly, so the test proceeds the instant the awaited state is reached
  and stays fully deterministic.

## References

- [Choosing Values for Robust Tests](https://testing.googleblog.com/2026/06/choosing-values-for-robust-tests.html)
  by Radion Khait
