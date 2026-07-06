# Values over Places (Rich Hickey)

A *value* is immutable and always means the same thing. A *place* is a
mutable location that holds a value at a point in time, and may hold a
different value tomorrow.

Prefer values. Pass values around; return new values from functions; avoid
holding references to shared mutable state. The payoffs:

- **Free sharing.** Values need no locks or coordination. You can pass them
  across threads, cache them, log them, and hand them to multiple callers
  without any of those callers affecting each other.
- **Reproducibility.** A function given the same value always sees the same
  input. A function given a reference to a place sees whatever someone else
  put there since you last looked.
- **Testability.** Transformations are pure functions: in, out, assert. No
  setup to establish prior state, no teardown to undo mutation.

Mutation has its place: building up a local result before returning it is
fine. The concern is mutation that *escapes*: modifying a caller's data,
writing to a shared reference, changing what a place holds in ways other
holders can observe.

Beware values that are secretly places. An object can present as immutable
while carrying mutable state internally, or be mutated in place by the code you
hand it to: a TLS context caches sessions and has its ALPN list rewritten by
the client that borrows it; a "config" object gets fields set by a downstream
consumer. "Read-only" is a claim to verify, not assume: before sharing or
caching such an object as if it were a value, confirm empirically that nothing
mutates it (see the verify-empirically rule).

Reference: [The Value of Values](https://www.infoq.com/presentations/Value-Values/) by Rich Hickey
