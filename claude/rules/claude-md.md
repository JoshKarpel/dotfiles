---
paths:
  - "**/CLAUDE.md"
---

# Authoring CLAUDE.md Files

## Don't Enumerate the Discoverable

Don't restate anything a reader could recover from the source: the `just` recipes
a justfile lists via `just --list` (usually wired to a default `list` recipe), the
npm scripts in `package.json`, the hooks registered in `settings.json`, the
scripts sitting in `bin/`. The copy drifts the moment someone adds an entry and
forgets the doc, and nothing fails when it does. Point Claude at the
self-describing source instead ("run `just --list` to see available recipes") so
the list is recovered on demand rather than maintained by hand. This is the
declarative rule's "recovered not restated" applied to Claude's own instructions.

The expensive form isn't a list of names, it's a **paragraph of behavior per
item**: what each hook matches, what each flag does, what each script classifies.
That's a prose reimplementation of the thing itself, and prose can't be tested, so
it rots silently while the code stays correct. The script _is_ the spec, and a
pointer to it never goes stale.

The test: could a reader get this by running one command or opening one named
file? Then link the command or the file. What survives the cut is what no single
source states on its own:

- Constraints not visible from any one file (hooks can't use functions from
  `sources/`, because they run in non-interactive subprocesses).
- Rationale for a design that otherwise looks arbitrary (why one hook sequences
  its checks instead of registering them as a group).
- Interactions between artifacts, where neither alone tells the story (a `deny`
  list stays thin _because_ another hook does the reasoning).
- A pointer to an exemplar worth copying, rather than a description of it.

The smell is a section that grows by a paragraph every time the thing it describes
grows by one entry. It has become a mirror of the source, and should be a link.

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
volatile metrics into durable docs" lives in the durable-docs rule.
