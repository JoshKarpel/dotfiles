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
