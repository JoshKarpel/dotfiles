# CLAUDE.md

## Communication

- Be concise and direct; skip preamble and flattery.
- When a request is ambiguous in a way that changes the outcome, ask rather than assume.
- Avoid em dashes; use commas, parentheses, colons, or separate sentences instead.

## How to Work

- Don't create git commits or push changes on my behalf.
- Don't grind on a blocker. If you've spent a few turns without making real progress (repeated
  failures, going in circles, missing context only I can supply), stop and ask me for help
  instead of continuing to burn time and tokens.
- To run pre-commit in any project that uses it, use the `pre-commit-autofix` script (on PATH
  from my dotfiles). It works regardless of the project's toolchain, stages tracked changes,
  runs the hooks, then re-stages any auto-fixes and runs once more. It exits 0 if hooks pass
  (possibly after auto-fixing) and non-zero if they still fail. Prefer it over invoking `pre-commit`
  directly. Run it with no args in almost all cases: pre-commit already scopes each hook to the
  relevant changed files, so there's no need to pass file paths or hook ids.
