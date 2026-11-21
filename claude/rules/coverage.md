---
paths:
  - "**/.coveragerc"
  - "**/pyproject.toml"
  - ".github/workflows/**"
---

# Coverage

- **Exclude a platform-only branch per platform, not everywhere.** A blanket
  coverage exclusion on a branch that only runs on another platform stops
  measuring it everywhere, so the gate goes quiet if that path dies. Exclude it
  only where it can't run, and gate each platform on its own run rather than on
  coverage data combined across a matrix: each job then passes or fails alone,
  a local run reaches the gate without the other platforms' data, and a miss
  names the platform that missed. The price is a pragma on every platform-only
  branch, which also marks it as such for the next editor. The exclusion still
  needs the gate to run where the branch does: with single-platform CI, a
  per-platform exclusion is a blanket one under another name. Building the
  other platform's shape locally
  (deleting the attribute the code probes for, constructing the other event loop
  directly) to test it for real everywhere is an option where it's cheap, not a
  prerequisite.
