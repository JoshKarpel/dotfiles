# Functional Core, Imperative Shell (Gary Bernhardt)

Separate pure business logic from code that has side effects.

- **Core:** pure functions: take data in, return data out, no I/O, no mutation,
  no global state. Easy to test, easy to reason about.
- **Shell:** orchestrates I/O (reading files, calling APIs, writing to
  databases), then feeds results into the core.

The goal is to push side effects to the outermost layer so the interesting
logic can be tested without mocking. Prefer making a function pure over making
it easier to mock.

Push boundary *decisions* out, not just effects. The same instinct that keeps
I/O in the shell keeps policy there too. A core that produces a typed value (an
HTTP response, a schema document) should not also bake in how that value crosses
the boundary: the serializer, the content type, the error-to-response mapping.
Return the value and let the shell choose the encoding, or inject the decision,
so the policy lives with the code that owns it and the core stays both pure and
reusable across shells that decide differently.

Reference: [Functional Core, Imperative Shell](https://www.destroyallsoftware.com/screencasts/catalog/functional-core-imperative-shell) by Gary Bernhardt
