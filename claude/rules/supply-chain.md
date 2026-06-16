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

## Cooldowns

Delay adopting a release until it has aged, as a defense against compromised or
malicious publishes. Use a relative duration (a sliding "last N days" window):
7 days is a reasonable default, with a longer window (e.g. 30 days) for major
version bumps. Pin a specific version to bypass the cooldown when you need a
fresh release. Configure it with each ecosystem's own knob.

## References

- [Package Managers Need to Cool Down](https://simonwillison.net/2026/mar/24/package-managers-need-to-cool-down/)
- [cooldowns.dev](https://cooldowns.dev/)
