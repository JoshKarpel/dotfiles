# Supply-Chain Hygiene for Dependencies

## Take on Fewer Dependencies

Every dependency is attack surface and a maintenance liability. Before adding
one, weigh it against the stdlib or a few lines of your own code. Prefer
well-maintained, widely-used packages with a real release history over a fresh
or single-maintainer package that happens to fit. A transitive dependency you
never chose is still yours to trust.

"A few lines of your own code" stops being cheaper in two cases, so take the
dependency there:

- **The code tracks an external standard.** Unicode widths and grapheme rules,
  time zones, MIME types, and public suffixes change on someone else's release
  schedule. A hand-rolled table is right on the day it's written and silently
  wrong after the next revision; a maintained package is updated for you.
- **Every project would write the same few lines.** A helper that each repo would
  otherwise reimplement (a coverage plugin, a test fixture library) is one
  dependency to vet once, against N private copies that drift apart.

## Pin and Lock

Commit a lockfile so resolution is reproducible and auditable: everyone, CI
included, installs the exact same versions, and a changed dependency shows up
as a reviewable diff. Don't float production dependencies on unpinned ranges
that silently pull whatever published most recently.

## One Installer per Tool

Every repo we control has a `mise.toml` alongside the package manager of each
language it's written in, and every development tool comes from exactly one of
them. A tool that a primary language's package manager can hold as a project dev
dependency goes there: ruff, `pre-commit-hooks` and zizmor in a Python repo's uv
dev group. Every other tool goes in `mise.toml`: the same hooks in a Rust or
shell repo, or a Go linter in a Python repo.

Nothing else installs a tool, pre-commit's hook environments included (see the
pre-commit style guide). Each tool then has one version, in one lockfile, behind
one cooldown, and the editor, task runner, hooks and CI all run that version.

## Floors for Libraries, Locks for Applications

Set a lower bound on each dependency, for the feature or fix you actually need,
and no upper bound. A cap is a claim about code that doesn't exist yet, and the
one thing you know about the next release is that you haven't tested it.

Reproducibility comes from the lockfile, not from caps in package metadata. A
published library's ranges are the *solvable space* it offers consumers; an
application's committed lockfile is the exact resolution it deploys. Caps narrow
the space for everyone downstream to buy a guarantee the lockfile already gives
you.

A PEP 723 inline script is an application too, so lock it:
`uv lock --script <script>` writes a `<script>.lock` beside it, which
`uv run --script` uses, and commit the lock. Without one, a run resolves afresh
every time, so even exact pins leave transitive dependencies floating to
whatever published last. Pin the direct dependencies exactly
(`counterweight==0.2.0`) as well, so an upgrade is a deliberate edit to the pin;
running the script after that edit relocks it. Set the cooldown in the script's
own metadata, since it has no project config to inherit one from:

```python
# /// script
# dependencies = ["counterweight==0.2.0"]
#
# [tool.uv]
# exclude-newer = "7 days"
# exclude-newer-package = { counterweight = false }
# ///
```

Cap only what you can point at: exclude a known-broken release (`!=1.4.2`), or
pin the single framework you extend (a pytest plugin, a Sphinx extension). Write
both as temporary, and remove them when the reason expires.

How much a cap costs depends on the resolver. Where one version of a package
serves the whole graph (Python, and any flat resolver), a cap in a transitive
dependency is unfixable from downstream: consumers get a silently older release,
or an unsolvable graph, and no amount of local pinning overrides it. Where the
graph holds several majors at once (Cargo, npm), a cap is local to the
dependency that set it, so `^`-style bounds are idiomatic there. Don't carry a
habit from one model into the other.

## Cooldowns

Delay adopting a release until it has aged, as a defense against compromised or
malicious publishes. Use a relative duration (a sliding "last N days" window):
7 days is a reasonable default, with a longer window (e.g. 30 days) for major
version bumps. Configure it with each ecosystem's own knob. How you take a fresh
release anyway depends on what the knob filters. mise's `minimum_release_age`
applies only to fuzzy resolution, so pinning a specific version bypasses it.
uv's `exclude-newer` hides every release inside the window, so a pin on one is
unsatisfiable, and the bypass is a per-package exemption
(`exclude-newer-package = { <package> = false }`).

## References

- [Should You Use Upper Bound Version Constraints?](https://iscinumpy.dev/post/bound-version-constraints/)
  by Henry Schreiner
- [Package Managers Need to Cool Down](https://simonwillison.net/2026/mar/24/package-managers-need-to-cool-down/)
- [cooldowns.dev](https://cooldowns.dev/)
