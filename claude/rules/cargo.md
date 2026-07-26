---
paths:
  - "**/Cargo.toml"
  - "**/rustfmt.toml"
  - "**/.rustfmt.toml"
  - "**/clippy.toml"
  - "**/.clippy.toml"
  - "**/rust-toolchain.toml"
  - "**/rust-toolchain"
---

# Cargo Project Configuration

Conventions for a Rust project's configuration files. For the language itself,
see the `rust` rule, which also loads here.

## Edition

Use the latest stable edition in `Cargo.toml` for new projects; don't change
the edition of an existing project as a side effect of other work.

## Toolchain

Which compiler builds the project, as distinct from the tools it invokes (those
are Tools, in the `rust` rule). Pin the channel and version at the repo root in
`rust-toolchain.toml`, so
contributors and CI share one compiler:

```toml
[toolchain]
channel = "1.96.0"
components = ["clippy", "rustfmt"]
```

Pin to stable. Where nightly is genuinely needed, reach for it per invocation with
`cargo +nightly <command>`, which overrides the pinned channel, rather than putting
the whole project on nightly. Install it once with
`rustup toolchain install nightly --component rustfmt`.

Two cases commonly need it:

- Unstable `rustfmt.toml` options, so formatting runs as `cargo +nightly fmt`.
- `#[bench]`/`test::Bencher`; the `rust` rule covers the alternatives.

## Dependencies

Preview how a dependency resolves before committing to it, then add it with an
explicit pinned version:

```bash
cargo add <crate> --dry-run
cargo add <crate>@<version>
```

`Cargo.lock` is committed, so keep it in step with anything edited in
`Cargo.toml` by hand. After bumping the package's own version,
`cargo update -p <package> --offline` refreshes just that entry without touching
dependencies or reaching the network.

## Formatting

Standard `rustfmt.toml`:

```toml
unstable_features = true

imports_granularity = "Item"
group_imports = "StdExternalCrate"

combine_control_expr = false

reorder_impl_items = true
```

- `imports_granularity = "Item"`: one `use` per imported item, so adding or
  removing an import touches a single line rather than reflowing a combined
  `use x::{a, b, c}`. Matches `isort.force-single-line` on the Python side.
- `group_imports = "StdExternalCrate"`: three import groups (std, external,
  crate-local).
- `combine_control_expr = false`: keeps `} else {` on separate lines.
- `reorder_impl_items = true`: sorts items inside `impl` blocks.

Every option above is unstable, so run `cargo +nightly fmt`. Stable rustfmt does
not fail on them: it prints `can't set ...` warnings and formats without them, so
formatting on stable quietly produces a different result than CI does.

## Linting

Run clippy with warnings as errors in CI:

```bash
cargo clippy --all-targets --all-features -- -D warnings
```

## References

- [The Cargo Book](https://doc.rust-lang.org/cargo/)
- [rustfmt configuration](https://rust-lang.github.io/rustfmt/)
- [Clippy lints](https://rust-lang.github.io/rust-clippy/master/)
