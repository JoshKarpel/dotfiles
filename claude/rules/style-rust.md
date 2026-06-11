---
paths:
  - "**/*.rs"
  - "**/Cargo.toml"
  - "**/rustfmt.toml"
  - "**/clippy.toml"
---

# Rust Style Guide

## Edition

Use `edition = "2021"` in `Cargo.toml`.

## Formatting

Standard `rustfmt.toml`:

```toml
unstable_features = true

imports_granularity = "Crate"
group_imports = "StdExternalCrate"

combine_control_expr = false

reorder_impl_items = true
```

- `imports_granularity = "Crate"` + `group_imports = "StdExternalCrate"`: three import groups (std, external, crate-local), one `use` per crate.
- `combine_control_expr = false`: keeps `} else {` on separate lines.
- `reorder_impl_items = true`: sorts items inside `impl` blocks.

## Linting

Run clippy with warnings as errors in CI:

```bash
cargo clippy --all-targets --all-features -- -D warnings
```

Add `#[allow(...)]` only when a lint is genuinely inapplicable; always include a comment explaining why.

## Derive

Derive aggressively rather than implementing by hand:

- `#[derive(Debug, Clone, PartialEq, Eq, Hash)]` — add what's applicable, in this order.
- **Serde**: `#[derive(Serialize, Deserialize)]`. Field names in `snake_case`; use `#[serde(rename_all = "camelCase")]` when the wire format differs.
- **Clap**: `#[derive(Parser)]` for top-level, `#[derive(Subcommand)]` for subcommand enums, `#[derive(Args)]` for argument groups.

## Error Handling

- Propagate with `?` throughout.
- Use `thiserror` for library errors: named error types with `#[derive(thiserror::Error)]`.
- Use `anyhow` for application-level propagation where the specific type doesn't matter at the call site.
- Avoid `.unwrap()` in library code. In application code, `.expect("reason")` is acceptable where a panic signals a programmer error — include a message that explains the invariant.

## Async

- `tokio` is the async runtime; annotate `main` with `#[tokio::main]`.
- Run independent futures concurrently with `tokio::join!` or `futures::future::join_all`; avoid sequential `await` chains for independent work.

## Toolchain

- **`cargo`** for building, testing, and dependency management
- **`rustfmt`** for formatting (`cargo fmt`)
- **`clippy`** for linting (`cargo clippy`)
- Pin the toolchain at the repo root with a `rust-toolchain` or `rust-toolchain.toml` file

## References

- [The Rust Reference](https://doc.rust-lang.org/reference/)
- [Rust API Guidelines](https://rust-lang.github.io/api-guidelines/)
- [The Rustonomicon](https://doc.rust-lang.org/nomicon/)
