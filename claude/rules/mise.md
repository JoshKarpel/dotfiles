---
paths:
  - "**/mise.toml"
  - "**/mise.*.toml"
  - "**/.mise.toml"
  - "**/.mise.*.toml"
  - "**/mise/config.toml"
  - "**/mise/conf.d/*.toml"
  - "**/.tool-versions"
---

# Mise Style Guide

## Global Config vs. a Project's `mise.toml`

Maintain both, deliberately, because they have different audiences:

- The **global config** is your own supporting toolchain: what you want on hand
  across projects, including tools no single repo declares (a profiler, a
  benchmarking harness, a diff viewer).
- A **project's `mise.toml`** declares only what that project needs, pinned, so a
  contributor gets a working setup from a clone. Every repo has one, holding the
  tools its primary languages' package managers can't (see the supply-chain
  rule).

A tool appearing in both is not duplication to resolve. The project's entry is the
contract; the global one is your convenience, and neither can stand in for the
other.

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
  `go:`, `github:owner/repo`, `aqua:`, or an `asdf:` plugin. This reaches most of
  crates.io / npm / PyPI / Go / GitHub releases.
- `ubi:` is deprecated (removed in mise 2027.1); use `github:owner/repo`, which
  also verifies GitHub artifact attestations and SLSA provenance on install.
- Prefer `github:` over `cargo:` for a Rust tool that publishes release binaries:
  `cargo:` builds it from source, which can take minutes per install.

## mise.lock

Commit a `mise.lock` in every repo, and install from it in CI with
`mise install --locked`.

For `pipx:`/`pypi:` tools, run `mise lock --upgrade` once to move the lockfile to
version 2, which records each tool's full dependency graph in a uv sidecar under
`.mise/locks/`; commit that directory too. A version-1 lockfile records only the
tool's own version, so its transitive dependencies float to whatever is newest at
install time. The sidecar's resolution honors `minimum_release_age`, so the
cooldown covers the graph even when the tool itself is pinned. Sidecars need
mise 2026.9.7 or newer and uv 0.12.10 or newer.

## Mirrors and Proxies

- Route mise's HTTP traffic through a mirror (an Artifactory remote, say) with
  `url_replacements` in `[settings]`. A key is a substring match unless it starts
  with `regex:`, so write each key with its full `https://` prefix: a bare
  `"github.com"` also rewrites `api.github.com`.
- Rewrite only the hosts the mirror actually proxies. A generic remote of
  `github.com` serves release downloads but not the API, so leave
  `api.github.com` alone and metadata and attestations keep working. Rewriting
  `api.github.com` also turns off mise-versions for GitHub metadata, sending every
  lookup through the mirror.
- `pipx:` tools install through `uv tool install`, and mise passes uv an index
  derived from `pypi.registry_url`, replacing `UV_INDEX_URL`. Point that setting
  at the mirror's simple index, `https://<host>/.../simple/{}/`: a JSON-API URL
  (`.../pypi/{}/json`) on any host but pypi.org converts to a broken index.
- Put the mirror's credentials in `~/.netrc`, which mise reads by default for
  Basic auth, never in the replacement URL.
- A mirror only some machines can reach goes in a machine-local file, not the
  shared global config: mise loads `~/.config/mise/conf.d/*.toml` alongside it.
  Where `~/.config/mise` is a symlink into a dotfiles repo, gitignore `conf.d/`.
- `MISE_TRACE=1 mise ls-remote <tool>` logs a `Replaced URL` line for each
  rewrite, and a real `mise install` exercises the download side.

## [env]

Prefer `.env` files for environment variables and secrets, not mise's `[env]`
section.

## [tasks]

Prefer `just`/`justfile` for task running, not mise's `[tasks]`.

## References

- [mise documentation](https://mise.jdx.dev/)
- [mise registry](https://mise.jdx.dev/registry.html)
