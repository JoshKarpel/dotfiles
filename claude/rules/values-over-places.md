# Values over Places (Rich Hickey)

A *value* is immutable and always means the same thing.
A *place* is a mutable location that holds a value at a point in time, and may
hold a different one tomorrow.

Prefer values: pass them around, return new ones from functions, and avoid
holding references to shared mutable state. The payoffs:

- **Free sharing.** Values need no locks or coordination: pass them across
  threads, cache them, log them, or hand them to several callers without any
  caller affecting another.
- **Reproducibility.** A function given a value always sees the same input;
  one given a place sees whatever someone else put there since you last looked.
- **Testability.** Transformations are pure functions: in, out, assert, with no
  setup to establish prior state and no teardown to undo mutation.

Building up a local result before returning it is fine.
The concern is mutation that *escapes*: modifying a caller's data, writing to a
shared reference, changing what a place holds where other holders can see it.

Beware values that are secretly places.
An object can present as immutable while carrying mutable state, or be mutated
in place by the code you hand it to: a TLS context caches sessions and has its
ALPN list rewritten by the client that borrows it; a "config" object gets
fields set by a downstream consumer.
"Read-only" is a claim to verify, not assume: before sharing or caching such an
object as if it were a value, confirm empirically that nothing mutates it (see
the verify-empirically rule).

Reference: [The Value of Values](https://www.infoq.com/presentations/Value-Values/) by Rich Hickey
