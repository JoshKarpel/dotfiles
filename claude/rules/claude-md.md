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
