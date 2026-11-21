# Testing

- **Test the functional core directly, and pass real objects in rather than
  patching.** Needing a mock to test a piece of logic means it is entangled
  with I/O: extract it into a pure function and test that.
  Where a dependency remains, pass a different argument
  instead of monkeypatching globals or module internals.
- **One behavior per test; arrange/act/assert; descriptive names.** Name a test
  for the behavior under test, not the function.
  A test covering several behaviors can only fail at one of them: split it.
- **Use non-default, distinct test values.** A broken function may produce a
  type default (`0`, `""`, the first enum entry) by accident,
  passing the test despite the bug.
  Give each of a function's inputs a _different_ value,
  so argument mix-ups and aliasing bugs surface.
- **Parametrize over copy-paste.** Exercise the same logic over different inputs
  with the testing library's parametrization:
  duplicated test bodies are as much a maintenance burden as duplicated
  production code.
- **Property-based testing when the input space is large.** Generated cases
  find edge cases that examples miss;
  prefer it when invariants are clearer than specific examples.
- **Pin join points with a round-trip test.** Where two independently
  maintained libraries must agree on a format, a test sending real bytes
  through both catches drift neither library's suite can see.
- **Assert only what the system determines.** For nondeterministic output
  (a model's text, a timing), assert the deterministic part:
  the status class, the schema, the invariant.
  An exact-output assertion there is flaky by construction.
- **Keep the feedback loop fast and local.** Every CI check should run the
  same way on a laptop, and the suite should be quick enough to run on every
  change, more so when an agent is iterating and runs it far more often than
  a person would.
- **Test at the boundary the parser establishes.** Concentrate edge-case tests
  where external input is parsed into internal types.
  Past that point, trust the types: don't re-test the parser in every
  downstream unit.
- **Suspect the check on a pass as well as a failure.** A probe can quietly
  measure the platform's own behavior instead of the thing under test:
  a browser restoring scroll position, a same-document navigation that never
  re-runs the script, a default that masks the branch you meant to exercise.
  A pass is no safer than a failure: a probe asking whether a permission allows
  a shell command teaches nothing if the subject satisfies the request another
  way and never attempts that command.
  A `pgrep -f` or `ps | grep` for a marker matches the probe's own shell,
  whose command line contains the marker,
  so "still alive" can be the probe finding itself.
  Confirm the probe reached the path you think it did before concluding
  anything from either outcome.
- **Prove a new test can fail.** A test that passes on its first run may be
  incapable of failing. Break the code deliberately, or run the test against a
  knowingly-broken copy, and confirm it fails before trusting it.
  This matters most where the obvious signal is constant:
  a script that always exits 0 has to assert a side effect instead,
  and an assertion on a side effect is easy to write in a form that holds
  either way.
  Undo the break with the inverse edit, or work on a copy:
  `git checkout --` and `git restore` revert the _whole_ file to HEAD,
  discarding every other uncommitted change in it,
  which mid-feature is most of the session's work.
  Restoring from a backup taken earlier fails the same way more slowly,
  since the backup predates whatever you fixed in between.
- **Break exactly the mechanism under test.** A break that disables more
  (inverting a parameter that feeds other paths too, or reverting to an
  approximation of the old code) makes the test fail for some other reason,
  which proves nothing about the claim it makes.
  Make the smallest break that removes only that mechanism,
  check that the failure names it,
  and when reverting to old behavior, reproduce the old code faithfully.
- **A green run is not a fixed race.** For a failure that was already
  intermittent, one pass is the expected outcome even with no fix at all,
  so it is not evidence.
  Before crediting a fix, check that its mechanism could actually produce the
  effect (does the hook run before or after the teardown it is supposed to
  observe?), then get a second, independent signal by re-running.
  A fix you can't explain mechanically is a coincidence you haven't caught yet.
- **Coverage is a floor, not a ceiling.** 100% line and branch coverage means
  every line ran, not that anything pins its behavior:
  a mutation that flips an `and` to an `or` can survive a fully-covering test
  that never varies the second operand.
  Where the logic is subtle and the project has a mutation testing setup,
  run it over new code and kill the survivors.
- **Substring assertions match the whole artifact.** Generated output that
  embeds a script's own source contains every selector that script mentions,
  and a negative assertion (`!output.contains("x")`) is satisfied by your own
  comment explaining why `x` is absent.
  Assert against the parsed element, or strip comments and embedded sources
  first.
- **A corpus sweep discovers; fixtures verify.** Running against real
  production data is how you find shapes you didn't anticipate.
  Once found, a shape becomes a committed fixture with a real assertion.
  "Nothing panicked across 300 files" is slow and proves almost nothing as a
  standing test.
- **No `sleep` to synchronize concurrent tests.** A fixed wait is both slow and
  flaky: any duration is either too short (racy under load) or too long
  (wasted wall-clock).
  Wait on the actual signal with whatever the concurrency model offers
  (an event, a queue, a condition variable, a future or promise, a channel,
  or joining the task), so the test proceeds the instant the awaited state is
  reached and stays deterministic.
- **Give the suite a global per-test timeout that dumps stacks and exits.**
  A hang is a failure that never reports: CI sits until the job limit and says
  "cancelled", with no hint which test or which line.
  An in-test timeout can't catch it either, since `asyncio.wait_for` and
  friends never fire while a thread is blocked in a syscall.
  A process-level watchdog can, so set one for the whole suite,
  generous enough that no healthy test comes near it.
  Bound a run against deliberately broken code the same way
  (`timeout 60 <test command>` if the suite has no watchdog yet):
  breaking a cancellation or concurrency path is exactly how a suite that used
  to finish starts hanging.
- **Check the machine's load before blaming the change for a timeout.**
  On a machine shared with other agents or builds, a watchdog firing or a suite
  slowing down often measures contention, not the diff.
  Run `uptime` first. Where the load is high, rerun on a quieter machine,
  or compare against the base branch on the same machine at the same moment,
  before investigating the change.
  A worker killed by the watchdog also drops its coverage data,
  so a coverage collapse right after a timeout is an artifact of the kill,
  not untested code.

## References

- [Choosing Values for Robust Tests](https://testing.googleblog.com/2026/06/choosing-values-for-robust-tests.html)
  by Radion Khait
