---
paths:
  - "**/CLAUDE.md"
---

# Authoring CLAUDE.md Files

## Don't Enumerate the Discoverable

Don't list, in the file, things a tool already reports on demand: individual
`just` recipes (a justfile is self-describing via `just --list`, usually wired
to a default `list` recipe), npm scripts, subcommands, or environment
variables. The list drifts out of sync the moment someone adds one and forgets
to update the doc. Point Claude at the self-describing source instead ("run
`just --list` to see available recipes") so the list is recovered on demand
rather than maintained by hand. This is the declarative rule's "recovered not
restated" applied to Claude's own instructions.

## What Belongs Here vs. in a Rule

A path-less rule and `CLAUDE.md` both load into every session at the same cost,
so the choice between them is editorial, not mechanical. Split by the *kind* of
guidance:

- **`CLAUDE.md` holds personal and harness operating instructions:** imperatives
  about how to work with this user and this tool (don't commit unprompted, don't
  grind on a blocker, pass an explicit `timeout`, prefer `ast-grep`). They're
  coupled to the person and the harness, not portable, and never cited by name.
- **A rule holds portable engineering doctrine:** each a named, linkable
  (`[[slug]]`), curatable unit that other rules reference by slug ("see the
  verify-empirically rule") and that carries its own rationale and references.
  That machinery only works because a rule is a discrete file, not a bullet in
  this monolith.

The test: could another rule cite it as a principle, or is it portable doctrine
with a rationale? Then it's a rule. Is it "how to work with me" or a
harness-specific quirk? Then it belongs here. When two pieces of guidance share
an instinct, keep the personal framing here and the citable doctrine in the
rule: "don't cite volatile metrics in replies" lives here, while "don't bake
volatile metrics into durable docs" lives in the documentation rule.
