# CLAUDE.md

## Communication

- Be concise and direct; skip preamble and flattery.
- When a request is ambiguous in a way that changes the outcome, ask rather than assume.
- Avoid em dashes; use commas, parentheses, colons, or separate sentences instead.
- Don't cite volatile exact metrics (test counts, file counts, coverage percentages) in
  summaries or replies; they go stale on the next change. Say "tests pass" or "mypy clean",
  not "238 tests across 68 files".

## How to Work

- Don't create git commits or push changes on my behalf.
- Don't grind on a blocker. If you've spent a few turns without making real progress (repeated
  failures, going in circles, missing context only I can supply), stop and ask me for help
  instead of continuing to burn time and tokens. This applies especially to third-party tool
  bugs (a type-checker artifact, a linter quirk): timebox it and reach for a workaround rather
  than root-causing someone else's tool.
- After a change with observable runtime behavior, exercise it end-to-end yourself (drive the
  flow, endpoint, or render) to confirm it works, rather than asking the user to eyeball it.
- When a Bash command is expected to run long (servers, load tests, builds, sweeps), pass an
  explicit `timeout` so the default 2-minute cap doesn't kill it mid-run and orphan child
  processes.
- Tear down processes you started via the background-task mechanism through that same mechanism,
  not `pkill`: killing a harness-tracked task reports a spurious failure exit.
- When you start a server just to check something, assume I may already be running the app on
  the default port; pick a non-default port and clean it up when done.
