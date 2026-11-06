# Verify Empirically

Confirm how a library, API, or runtime actually behaves before you build on it,
including the invariants it claims ("read-only", "thread-safe", "idempotent").
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
  don't have. When `--help` doesn't explain a flag interaction you're seeing, read
  the tool's source at its exact pinned tag rather than inferring the semantics:
  a flag that sets a value may still fall through to the behavior you thought it
  replaced.
- **Platform behavior is a claim, not a fact.** How a third-party service renders,
  serves, or size-limits something is worth one request against the real service
  before any code depends on it. A remembered, precise-sounding threshold ("renders inline under
  ~1 MB") is exactly the kind that proves false only after a feature, its tests,
  and its docs are built on it.
- **Search the tracker before calling it a bug.** Third-party behavior that looks
  wrong from reading the source is a hypothesis, not a finding: widely used code has
  usually been hit before. Before telling the user a dependency is buggy or proposing
  an upstream change, search its issue tracker, changelog, and releases for that
  behavior. The likeliest result is a known issue already fixed in a newer release,
  which turns "file a bug" into "upgrade".
- **The repo's own docs are claims too.** A `CLAUDE.md` gotcha, a README
  troubleshooting note, or a code comment explaining runtime behavior was written
  by someone who saw it once, possibly misread it, and the system may have changed
  since. Probe the mechanism before acting on one when being wrong costs
  something (deleting data, restarting a service, telling the user to), and
  before recording a diagnosis of your own as one: a note written from one
  observation reads to the next session as settled fact. When the probe
  disagrees, fix the doc in the same change.
- **Run the control before trusting the experiment.** A reproduction harness you
  just built is itself unproven, so a run that confirms your hypothesis may be
  measuring the harness instead: a nested container with no init system, a health
  command the runtime takes literally, a probe that never reached the code path.
  Run the known-good case through the same harness first and confirm it comes out
  known-good. If the control fails too, what you have is a broken rig, not a
  reproduction.
- **Never state a performance claim you haven't measured**, least of all in a
  comment or doc. Plausible reasoning about what amortizes or what dominates is
  frequently backwards, and a measurement is usually one command away. The same
  goes for proportions: without numbers for how usage or traffic splits, state
  the dependence ("grows as more clients adopt v2"), not the balance ("most
  traffic is v2"). Likewise, a limit that a routine request lifts (a default quota, a rate
  cap) isn't a cost of the design unless you've checked that it binds.

This is parse-don't-validate applied to your own knowledge: don't trust a
remembered fact at a boundary; establish it from ground truth.
