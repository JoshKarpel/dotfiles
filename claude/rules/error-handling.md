# Error Handling

- **Let unexpected input fail.** When data doesn't match what the code expects,
  prefer failing over silently skipping or swallowing it. Quietly dropping a
  malformed file or an unrecognized case hides the problem; a loud failure
  surfaces what can go wrong so we can decide how to handle it deliberately.
- **Valid-but-optional is not malformed.** "Fail loud" applies to input that
  violates the contract, not to input that satisfies it in a way this consumer
  doesn't care about. A producer adding an optional field (a new event kind, a
  trailing header) must never crash a consumer that didn't ask for it; ignoring
  it is a deliberate choice, not a swallowed error. Put strictness only where
  something is *required*: the consumer that demands the value raises in its own
  terms when it's absent, instead of every consumer rejecting anything extra.
- **Don't add error handling, fallbacks, or validation for paths that can't
  occur.** No defensive checks for cases the types or call sites already rule out.
- **Don't bubble-wrap preemptively.** Resist wrapping things in `try`/`except`
  and failure logging before you know it's needed. Let experience show where
  handling earns its place; speculative handling adds noise and buries real bugs.
- This tension is sharper in exception-based languages (Python), where a bare
  `except` or a defensive `.get()` swallows problems invisibly, than in
  result-based ones (Rust), where the type system forces the error to the surface.
- The strongest form of "don't handle what can't occur" is to make it
  unrepresentable: design types so the bad state can't be constructed in the
  first place. See the parse, don't validate rule.
