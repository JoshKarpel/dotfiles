# Verify Empirically

Confirm how a library, API, or runtime actually behaves before you build on it.
Memory of an interface drifts: names, signatures, defaults, and edge behaviors
change between versions, and a confident recollection is often wrong. When a
change hinges on external behavior, write a throwaway probe (a few lines run
against the real dependency) and read the result rather than coding from what
you think the API does.

- **Probe before you build.** Before wiring code against an unfamiliar library
  or a stdlib corner you're unsure of, run a minimal script that exercises the
  exact call you'll rely on. A wrong assumption caught by a five-line probe is
  cheaper than one discovered after the dependent code, tests, and docs are
  already written around it.
- **Check the installed version, not "latest".** Hosted docs usually track the
  newest release, which may be ahead of what this project pins. Find the
  resolved version with the packaging tool (`uv pip show <pkg>` / `uv tree`,
  `cargo tree`), then verify behavior against *that* version: read its source
  (`inspect.getsource`, the installed package files) or run it. For a CLI, ask
  the tool itself, `--version` for what's installed and `--help` (or subcommand
  help) for the actual interface, rather than a docs page for a version you
  don't have.
- **Treat invariants as claims to test.** "Read-only", "immutable",
  "thread-safe", "idempotent" are properties to confirm, not assume. An object
  can look like a value while holding mutable state (see the values-over-places
  rule).

This is parse-don't-validate applied to your own knowledge: don't trust a
remembered fact at a boundary; establish it from ground truth.
