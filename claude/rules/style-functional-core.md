# Functional Core, Imperative Shell (Gary Bernhardt)

Separate pure business logic from code that has side effects.

- **Core:** pure functions: take data in, return data out, no I/O, no mutation,
  no global state. Easy to test, easy to reason about.
- **Shell:** orchestrates I/O (reading files, calling APIs, writing to
  databases), then feeds results into the core.

The goal is to push side effects to the outermost layer so the interesting
logic can be tested without mocking. Prefer making a function pure over making
it easier to mock.

Reference: [Functional Core, Imperative Shell](https://www.destroyallsoftware.com/screencasts/catalog/functional-core-imperative-shell) by Gary Bernhardt
