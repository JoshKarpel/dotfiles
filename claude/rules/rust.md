---
paths:
  - "**/*.rs"
  - "**/Cargo.toml"
  - "**/rustfmt.toml"
  - "**/.rustfmt.toml"
  - "**/clippy.toml"
  - "**/.clippy.toml"
  - "**/rust-toolchain.toml"
  - "**/rust-toolchain"
---

# Rust Style Guide

Conventions for Rust source: derives, language features, arithmetic, error
handling, async, and benchmarking.

## Derive

Derive aggressively rather than implementing by hand:

- `#[derive(Debug, Clone, PartialEq, Eq, Hash)]`: add what's applicable, in this order.
- **Serde**: `#[derive(Serialize, Deserialize)]`. Field names in `snake_case`; use `#[serde(rename_all = "camelCase")]` when the wire format differs.
- **Clap**: `#[derive(Parser)]` for top-level, `#[derive(Subcommand)]` for subcommand enums, `#[derive(Args)]` for argument groups.

`#[serde(other)]` on an internally tagged enum only rescues an *unrecognized tag*.
A recognized tag carrying a wrong-typed field is still a hard deserialization
error, and unknown *fields* on a known variant are ignored either way. Don't lean
on it as a general leniency switch for an evolving external format.

## Language Features

- **Let-chains** (`if flag && let Some(value) = option`) require **edition 2024**;
  they are a compile error on 2021 and earlier. Use one instead of nesting an
  `if let` inside an `if`.
- Exclusive and open-ended range patterns in `match` (`..60`, `60..3600`) are
  stable. Clippy rejects *overlapping* arms, so write the explicit lower bound
  rather than a bare open-ended range beside an adjacent boundary.

## Lint Suppression

Add `#[allow(...)]` only when a lint is genuinely inapplicable; always include a
comment explaining why.

## Arithmetic

Offset and span math takes checked arithmetic, propagating rather than trusting
raw `+`/`-`:

```rust
offset.checked_add(limit.checked_sub(1)?)?
```

A raw expression panics in debug and wraps in release, and the boundary cases (a
`limit` of `0`, a range running past the integer's width) are exactly the ones a
fixture corpus won't contain.

## Build Scripts

Data that is a pure function of files already known at build time (encoding,
embedding, table generation) belongs in `build.rs`, written to `OUT_DIR` and
pulled in with `include_str!`/`include!`, not computed at startup behind a
`LazyLock`. Commit the generated artifact when regenerating it needs network
access or tooling CI doesn't run: `build.rs` reading it means a fresh clone
otherwise fails to build.

## Error Handling

- Propagate with `?` throughout.
- Use `thiserror` for library errors: named error types with `#[derive(thiserror::Error)]`.
- Use `anyhow` for application-level propagation where the specific type doesn't matter at the call site.
- Avoid `.unwrap()` in library code. In application code, `.expect("reason")` is acceptable where a panic signals a programmer error; include a message that explains the invariant.

## Async

- `tokio` is the async runtime; annotate `main` with `#[tokio::main]`.
- Run independent futures concurrently with `tokio::join!` or `futures::future::join_all`; avoid sequential `await` chains for independent work.

## Benchmarking and Profiling

`#[bench]`/`test::Bencher` is nightly-only, so on a stable-pinned project choose
deliberately between an external harness and a dev-dependency: hyperfine over the
built binary measures what a user actually waits on (process startup included) and
costs no compile time, while `criterion`/`divan` attribute time within the process.

Profiling gets its own profile, so a shipped binary doesn't carry symbols nobody
reads:

```toml
[profile.profiling]
inherits = "release"
debug = true
```

Throwaway measurements and sanity checks go in `examples/`, run with
`cargo run --release --example <name>`, and are deleted afterwards: a real
optimized binary without touching `tests/` or leaving dead code behind.

For the recording and reading workflow, and the several ways a Rust profile
misleads, use the `optimize-rust` skill.

## Tools

- **`cargo`** for building, testing, and dependency management
- **`rustfmt`** for formatting (`cargo fmt`)
- **`clippy`** for linting (`cargo clippy`)

## References

- [The Rust Reference](https://doc.rust-lang.org/reference/)
- [Rust API Guidelines](https://rust-lang.github.io/api-guidelines/)
- [The Rustonomicon](https://doc.rust-lang.org/nomicon/)
