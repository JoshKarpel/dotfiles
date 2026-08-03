# Supply-Chain Hygiene for Dependencies

## Take on Fewer Dependencies

Every dependency is attack surface and a maintenance liability. Before adding
one, weigh it against the stdlib or a few lines of your own code. Prefer
well-maintained, widely-used packages with a real release history over a fresh
or single-maintainer package that happens to fit. A transitive dependency you
never chose is still yours to trust.

## Pin and Lock

Commit a lockfile so resolution is reproducible and auditable: everyone, CI
included, installs the exact same versions, and a changed dependency shows up
as a reviewable diff. Don't float production dependencies on unpinned ranges
that silently pull whatever published most recently.

## Floors for Libraries, Locks for Applications

Set a lower bound on each dependency, for the feature or fix you actually need,
and no upper bound. A cap is a claim about code that doesn't exist yet, and the
one thing you know about the next release is that you haven't tested it.

Reproducibility comes from the lockfile, not from caps in package metadata. A
published library's ranges are the *solvable space* it offers consumers; an
application's committed lockfile is the exact resolution it deploys. Caps narrow
the space for everyone downstream to buy a guarantee the lockfile already gives
you.

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
version bumps. Pin a specific version to bypass the cooldown when you need a
fresh release. Configure it with each ecosystem's own knob.

## References

- [Should You Use Upper Bound Version Constraints?](https://iscinumpy.dev/post/bound-version-constraints/)
  by Henry Schreiner
- [Package Managers Need to Cool Down](https://simonwillison.net/2026/mar/24/package-managers-need-to-cool-down/)
- [cooldowns.dev](https://cooldowns.dev/)
