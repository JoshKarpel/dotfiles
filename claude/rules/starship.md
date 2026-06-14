---
paths:
  - "**/starship.toml"
---

# Starship Prompt

[starship](https://starship.rs/) config is global at `~/.config/starship.toml`.
The full module reference is the [config docs](https://starship.rs/config/):
consult it before adding or tuning a module rather than guessing at field names.

## Modules

- Most modules are enabled by default. Language/runtime version modules
  (`nodejs`, `rust`, `python`, etc.) read the version off `PATH`, so they pick
  up whatever mise has activated without extra wiring.
- Several useful modules are off by default and must be opted into with
  `disabled = false`: `kubernetes` (context + namespace), `status` (last exit
  code), `git_metrics` (added/removed line counts).

## Keep the prompt fast

Every module that shells out runs on each prompt render, on the interactive
hot path. Enable these deliberately, not by reflex:

- `kubernetes` parses kube config, `git_metrics` runs `git diff`, and the
  `mise` health module runs `mise doctor` on every render.
- The `mise` module only reports health (installed/healthy), not versions; the
  language modules already cover versions, so it is rarely worth its cost.

## References

- [starship config docs](https://starship.rs/config/)
- [module presets](https://starship.rs/presets/)
