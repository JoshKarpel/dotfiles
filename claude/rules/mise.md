---
paths:
  - "**/mise.toml"
  - "**/mise.*.toml"
  - "**/.mise.toml"
  - "**/.mise.*.toml"
  - "**/mise/config.toml"
  - "**/.tool-versions"
---

# Mise Style Guide

## [tools]

- Keep entries sorted alphabetically.
- `"latest"`/`"lts"` are reasonable default versions in global config; in a
  repo's `mise.toml`, pin specific versions for reproducibility.
- Set a `minimum_release_age` cooldown (e.g. `"7d"`) in `[settings]` so fuzzy
  resolution skips brand-new releases, as supply-chain protection. Pinned
  versions bypass it.
- List language runtimes and single-binary CLI tools here. Prefer a mise entry
  over a global `npm -g` / `pipx` / `cargo install`: it's declarative and
  survives runtime reinstalls.
- Don't list a tool here as a substitute for its own resolver/workflow (uv,
  package managers), and don't list system packages (apt/brew libraries,
  daemons, GUI casks). Install the binary with mise if you need it; keep the
  workflow.

### Discovering what mise can manage

- Curated short names: `mise registry` lists them, `mise registry <name>` shows
  the mapping, and `mise ls-remote <tool>` lists a tool's versions.
- Not in the registry? Use a backend-prefixed name: `cargo:`, `npm:`, `pipx:`,
  `go:`, `ubi:owner/repo`, `aqua:`, or an `asdf:` plugin. This reaches most of
  crates.io / npm / PyPI / Go / GitHub releases.

## [env]

Prefer `.env` files for environment variables and secrets, not mise's `[env]`
section.

## [tasks]

Prefer `just`/`justfile` for task running, not mise's `[tasks]`.

## References

- [mise documentation](https://mise.jdx.dev/)
- [mise registry](https://mise.jdx.dev/registry.html)
