# Parse, Don't Validate (Alexis King)

At system boundaries, *parse* input into a richer type that encodes the
invariant; don't just check a condition and discard the result.
A validator returns nothing useful (at most a boolean), so callers must still
handle bad data downstream.
A parser returns a refined type that *proves* the invariant was satisfied,
eliminating downstream checks.

- **Make illegal states unrepresentable.** Choose types that can't express
  invalid values: a list that must be non-empty gets a `NonEmpty`-style type,
  not a runtime assertion.
- **Parse at the boundary, once.** Validate and transform external input where
  it enters the system, so internal code works only with already-valid types,
  with no defensive re-checks.
- **Distrust functions that return `void`/`None` for error-checking.** A
  function whose job is to verify something should return the verified data; a
  `None` return means the information was thrown away.
- **Avoid denormalized state.** Two fields that must be kept in sync are an
  invalid state waiting to happen; refactor to a single source of truth.
- **Default-value policy follows role, not shape.** A type a parser fills from
  outside input (inbound) carries *no* defaults, so a field the parser forgot
  fails loudly instead of silently defaulting: a parsed type must prove every
  field was supplied, and a defaulted one cannot.
  A type the caller constructs (outbound) carries defaults for ergonomic
  construction.
  Even when two types have identical fields, don't reuse one across the
  boundary: they hold opposite invariants.

Reference: [Parse, Don't Validate](https://lexi-lambda.github.io/blog/2019/11/05/parse-don-t-validate/) by Alexis King
