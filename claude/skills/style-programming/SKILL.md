---
name: style-programming
description: >
  General programming style guide. Use whenever writing or significantly editing
  code in any language. Covers parse-don't-validate, functional core/imperative
  shell, comment policy, naming, error handling, and function design.
---

# General Programming Style

## Adopt Local Conventions

When working in an existing codebase, match what's already there:
naming conventions, patterns, libraries in use. Consistency within a codebase
matters more than any external style guide, including this one. Override local
conventions only where there's a clear and specific reason to diverge.

This principle applies to all language-specific style guides too.

## Parse, Don't Validate (Alexis King)

At system boundaries, *parse* input into a richer type that encodes the invariant —
don't just check a condition and discard the result.

The difference: a validator returns nothing useful (or just a boolean), so callers
must still handle the possibility of bad data downstream. A parser returns a refined
type that *proves* the invariant was satisfied, eliminating downstream checks.

- **Make illegal states unrepresentable.** Choose data structures and types that
  can't express invalid values. If a list must be non-empty, use a `NonEmpty`-style
  type, not a runtime assertion.
- **Parse at the boundary, once.** Validate and transform external input right where
  it enters the system. Internal code should work only with already-valid types;
  no defensive re-checks.
- **Distrust functions that return `void`/`None` for error-checking.** If a function's
  job is to verify something, it should return the verified data. A return type of
  `None` means the information was thrown away.
- **Avoid denormalized state.** Two fields that must be kept in sync are an invalid
  state waiting to happen. Refactor to a single source of truth.

## Functional Core, Imperative Shell (Gary Bernhardt)

Separate pure business logic from code that has side effects.

- **Core:** pure functions: take data in, return data out, no I/O, no mutation,
  no global state. Easy to test, easy to reason about.
- **Shell:** orchestrates I/O (reading files, calling APIs, writing to databases),
  then feeds results into the core.

The goal is to push side effects to the outermost layer so the interesting logic
can be tested without mocking. Prefer making a function pure over making it easier
to mock.

## Simple vs. Easy (Rich Hickey)

**Simple** means unentangled: one concern, no interleaving with other things.
It's objective: you can inspect a piece of code and determine whether it's braided
together with something else or truly independent.

**Easy** means familiar or close at hand. It's subjective and person-relative.

These are orthogonal. Don't confuse ease of writing with simplicity of the result.
A construct that's fast to reach for can produce a complected system; a harder
upfront choice can produce one that's easy to change for years.

**Complecting** is Hickey's term for braiding together things that could be
independent: state with identity, function with state, timing with logic,
policy with mechanism. It's how complexity accumulates. When something feels
hard to change or reason about, look for what it's been complected with.

Optimize for the simplicity of the artifact (the running system), not the
convenience of the author. Easy-to-write code that's complected is a
slow-burning problem.

## Making Changes (Kent Beck)

> For each desired change, make the change easy (warning: this may be hard),
> then make the easy change.

When asked to make a change, assume similar changes will follow. Before diving in,
ask whether the code is in the right shape to receive not just this change but the
next few like it. If not, restructure so that this and future changes become easy.

Avoid one-off solutions. Prefer building systems out of composable building blocks,
so each new requirement snaps into place rather than requiring bespoke logic.

## Dependency Injection

Pass dependencies explicitly as arguments to functions and to class constructors.
Don't reach for globals, service locators, or DI frameworks.

Benefits of this approach:
- Dependencies are visible at the call site: no hidden coupling
- No mocking needed in tests; just pass a different argument
- Lifetime and singleton concerns bubble up naturally to the caller,
  where they can be handled once in a centralized place (e.g., application startup)
- No framework magic to learn, debug, or work around

The pattern scales well: at the outermost layer (CLI entrypoint, server lifespan,
test fixture), construct shared objects once and pass them down. Inner code stays
pure and unaware of how those objects were created.

## Testing

One of the payoffs of functional-core/imperative-shell, parse-don't-validate, and
dependency injection is that testing becomes easy: pure functions take data in
and return data out, so tests are plain assertions; and dependencies are just
arguments, so tests pass in whatever they need without patching.

- **Test the functional core directly, without mocks.** If you find yourself
  mocking to test a piece of logic, the logic is probably entangled with I/O.
  Extract it.
- **Prefer real objects via dependency injection over patching.** Pass a
  different argument in tests rather than monkeypatching globals or module
  internals.
- **One behavior per test; arrange/act/assert; descriptive names.** A test name
  should state the behavior under test, not the function name. If a test covers
  multiple behaviors, it can only fail at one of them: split it.
- **Parametrize over copy-paste.** When the same logic is exercised with
  different inputs, use the testing library's parametrization facility. Duplicated test
  bodies are as much of a maintenance burden as duplicated production code.
- **Property-based testing when the input space is large.** Generating many
  cases finds edge cases that example-based tests miss. Prefer it when invariants
  are clearer than specific examples.
- **Test at the boundary the parser establishes.** Concentrate edge-case tests
  at the point where external input is parsed into internal types. Once data is
  internal, trust the types: don't re-test the parser in every downstream unit.

## Comments

Write no comments by default. Add one only when the WHY is non-obvious:
a hidden constraint, a subtle invariant, a specific bug workaround,
or behavior that would genuinely surprise a future reader.

Never explain what the code does. Well-named identifiers do that.
Never reference the current task, PR, or callers: those belong in commit messages,
not code, and they rot as the codebase evolves (unless it's a forward-looking TODO).

## Functions

- Prefer flat code over deep nesting. Use early returns instead of nested conditionals.
- Don't add error handling, fallbacks, or validation for paths that can't occur.

## Naming

- Names should describe *what*, not *how*.
- Prefer clear, full words over abbreviations.
- Boolean names should read as predicates: `is_valid`, `has_error`, `can_retry`.
- Avoid filler words: `data`, `info`, `manager`, `handler`, `util` are smells.

## Toolchain

- **[`just`](https://just.systems/man/en/)** as the command runner for project tasks

## References

- [Parse, Don't Validate](https://lexi-lambda.github.io/blog/2019/11/05/parse-don-t-validate/) by Alexis King
- [Simple Made Easy](https://github.com/matthiasn/talk-transcripts/blob/master/Hickey_Rich/SimpleMadeEasy.md) by Rich Hickey
- [Functional Core, Imperative Shell](https://www.destroyallsoftware.com/screencasts/catalog/functional-core-imperative-shell) by Gary Bernhardt
