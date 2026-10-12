# Equivalent-mutant catalogue

Shapes of surviving mutant that no test can kill, each with the argument that clears it. A
survivor that matches one of these still needs that argument made _for its own line_: the
category says where to look, not that the case is closed. Several of them are equivalent only
because of a fact outside the mutated line (a guard above, a library's own invariant), and that
fact is what the project's write-up should name.

Each one also has a near neighbour that is _not_ equivalent, called out below. Mistaking the
neighbour for the category is the usual way a real hole gets written off.

## Contents

- Match-case drops
- Loop control the loop condition already decides
- Truthiness-preserving swaps
- Order-preserving changes to a sort key
- Fast paths a slower arm already handles
- Case swaps on case-insensitive literals
- Arguments the callee ignores or resolves to the same value
- Exception sets that already contain the dropped type
- Conjunctions an earlier guard makes redundant
- Alternatives that fail into the same answer
- Unreachable boundaries and defaults
- Diagnostic prose
- Arguments discarded by a later absolute conversion
- Unobservable defensive paths
- A killing test excluded from the run

## Match-case drops

`operator_match` drops one `case` at a time from every `match` with two or more cases. Dropping
an exhaustiveness arm is equivalent, since only a value the type checker forbids could reach it:

```python
match event:
    case Start(): ...
    case Body(): ...
    case _ as unreachable:
        assert_never(unreachable)  # dropping this case: every valid value matched above
```

No pragma or pattern suppresses a case drop (see the skill's suppression section), so these are
always survivors to document. Dropping a trailing case whose body is a no-op (`continue` at the
bottom of a loop) is equivalent too, but there the better fix is to delete the case so there is
nothing to drop.

## Loop control the loop condition already decides

`continue` becomes `break` (and `break` becomes `return`). Where the loop's own condition is
already false at that point, `continue` and `break` both leave the loop, so the swap is
invisible. Prove the condition is false there from the code above it, not from the tests.

Not equivalent: the same swap anywhere the loop has more work left. Stopping a fill loop early
usually shows up only as _lost concurrency or delayed work_, so the killing test pins a
scheduling property (siblings start in the same round), not just the final result.

## Truthiness-preserving swaps

`False` becomes `None`, `b""` becomes `None`, `x = []` becomes `x = None` and so on. A value
that is only ever read in a boolean context (`if flag`, `not flag`, `and`/`or`) behaves the same
under any swap that preserves its truthiness. This includes a keyword argument the callee reads
only for truthiness: probe the callee with `True`, `False`, and `None` and check that the latter
two agree, against a control where `True` visibly differs.

A `# pragma: no mutate` is usually wrong here, because the same line's `False -> True` mutant is
a real change that a test should kill, and the pragma blinds both.

## Order-preserving changes to a sort key

A function used only as `sorted(..., key=f)` is equivalent under any change that keeps the
ordering: `return 1 if special else 0` survives `1 -> 2`. Only the comparison between keys is
observable.

## Fast paths a slower arm already handles

An exact-type check ahead of an `isinstance` ladder (`if type(x) is str: ... elif
isinstance(x, str): ...`) gives the same input two routes to the same result. Mutants that
disable the fast arm (`type(None) is str`, `and` flipped to `or` on a shadowed pair) send the
input down the slow arm, which produces the identical output. The fast arm buys speed, which no
functional test observes. Check that the slow arm's body really is a duplicate or a superset
that resolves to the same value; a slow arm that differs (escapes where the fast arm doesn't)
makes the mutant killable.

## Case swaps on case-insensitive literals

`operator_string` produces three mutants per literal: an `XX...XX` wrap, a lower-cased copy, and
an upper-cased copy. Where the consumer is case-insensitive, the case swaps survive and the wrap
is killed (it is an invalid name):

- codec names (`"ascii"`, `"latin-1"`): codec lookup ignores case;
- SQL keywords, pragma names, and pragma values;
- HTTP header names passed to a case-insensitive _lookup_.

Hoist such a literal into one local or attribute per module rather than repeating it at each
call site, so there is one survivor to document instead of one per use. Not equivalent: a header
name being _written_, which is emitted verbatim.

When verifying a database-side claim, use a real file-backed database: an in-memory SQLite
database reports `memory` for every journal mode, so a probe there proves nothing.

## Arguments the callee ignores or resolves to the same value

- `typing.cast(T, x)` never looks at `T`, so `cast(None, x)` survives. A pragma would also blind
  the value-expression mutants on that line, which are real.
- `loop=loop` passed to an asyncio constructor that would call `get_event_loop()` itself and get
  the same running loop: both `loop=None` and the dropped keyword survive.
- An optional collaborator the callee consults only on a path the caller never reaches.

## Exception sets that already contain the dropped type

`suppress(Base, Subclass)` or `except (Base, Subclass)`: dropping `Subclass`, or replacing it
with `None`, leaves the caught set unchanged. Dropping `Base` is a different mutant, killable
only if something raises a non-`Subclass` `Base` inside the block; often that is not
deterministically reachable, which is a separate argument to make.

## Conjunctions an earlier guard makes redundant

```python
if type(one) is not type(other):
    return False
if isinstance(one, Mapping) and isinstance(other, Mapping):  # mutant: and -> or
```

Past the type check both operands give the same answer, so `or` admits what `and` admits. The
same holds when an external invariant (a library that only calls `resume` after `pause`) means
neither clause can be false while the other is true. The redundant operand may still be needed
for type narrowing, so it is a survivor to explain, not a line to simplify.

## Alternatives that fail into the same answer

`partition` and `rpartition` (or `find`/`rfind`, `split`/`rsplit` with `maxsplit`) differ only
on input holding the separator twice. If every such input fails parsing either way, and the
failure path returns the same fallback, the swap is equivalent. The same applies when a
`"XX,XX"` wrap stops a membership check from recognising a case, and the unrecognised input then
fails a later parse into the identical fallback. These look like holes, and the reasoning that
clears them is not local to the mutated line, so write it down.

`<` becoming `<=` on a scan loop is equivalent when the extra iteration sees an empty slice that
the body skips without changing the result.

## Unreachable boundaries and defaults

- `if closing < 0` surviving as `<= 0` when `find` was called from `index + 1`, so the result is
  `-1` or at least `1` and zero is unreachable.
- A default in `next(gen, default)` or `d.get(k, default)` that an upstream validator guarantees
  is never used.
- A size-policy boundary (`>=` vs `>` on "output no smaller than input") whose equality case
  needs an input that lands exactly on it: a fixture pinned to that is a flake waiting for the
  next library release, so cover the neighbouring behaviour instead.

## Diagnostic prose

Log and exception message text mutated by an `XX` wrap or a case swap survives when the tests
assert what a message must _carry_ (the identifier, the count, the errno, the filename) rather
than its wording. That is the right trade: pinning prose freezes wording that should stay
editable. `pytest.raises(match=...)` is a `re.search`, so an unanchored match survives the wrap
too; where the exact text is the contract (a library's public error), anchor it with `^...$`.

Not equivalent: a `logger.info(None)` or a dropped argument, which loses the content. A test that
asserts the content kills it.

## Arguments discarded by a later absolute conversion

`datetime.fromtimestamp(ts, UTC)` surviving as `fromtimestamp(ts, None)` when the value is only
ever turned back into an absolute instant (`.timestamp()`, a GMT formatter). Verify across a DST
transition, where local time is ambiguous. Not equivalent when the datetime itself is exposed:
naive versus aware is observable.

## Unobservable defensive paths

Mutations inside error handling whose effect is masked downstream: a header name that the
protocol library lower-cases on the wire, a write whose bytes are already buffered elsewhere and
re-flushed, a crash in a task after the response has been sent. Verify each empirically before
claiming it, and prefer a test when the mask is incidental rather than guaranteed.

## A killing test excluded from the run

A mutant can be killable in principle while its only killing test is deselected from the
mutation run (because it fails mutmut's baseline for trampoline reasons). It survives, and the
write-up should name the test that would kill it, so the residue is explained rather than
mysterious.
