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
- Auto-memory is off, so nothing persists automatically between sessions. When something
  is worth keeping past this one, put it in a committed artifact: a rule in
  `claude/rules/` for portable doctrine, `CLAUDE.md` for how-to-work-with-me guidance, a
  skill for a procedure, a hook for something the harness should enforce. Ask where it
  belongs when that isn't obvious, rather than dropping it in the nearest file.
- Context that belongs in every session but is only true at a point in time wants a
  `SessionStart` hook that computes it, not a hand-maintained list that drifts. Repo
  state, available recipes, the current toolchain version: derive it at startup so it
  can't go stale.
- Change file contents with the Edit tool, not `sed`/`python`/heredoc text surgery.
  Hand-rolled replacement skips the uniqueness check, hides the change inside an
  opaque command, and bypasses the harness's file-state tracking, which then
  reports "modified on disk since you last read it" and tempts yet more scripting.
  This covers creating and appending, not just editing: `cat > f <<EOF` and
  `cat >> f <<EOF` are the same untracked write, and Write (or an Edit anchored on
  the last few lines) is the tool for both, throwaway probe scripts included.
- A command that was blocked or that failed did nothing. Don't assume any artifact
  it would have produced exists; re-run it before anything downstream reads that
  output, or you'll debug a stale file instead of the actual change.
- Don't grind on a blocker. If you've spent a few turns without making real progress (repeated
  failures, going in circles, missing context only I can supply), stop and ask me for help
  instead of continuing to burn time and tokens. This applies especially to third-party tool
  bugs (a type-checker artifact, a linter quirk): timebox it and reach for a workaround rather
  than root-causing someone else's tool.
- When you stop because you're stuck, hand off rather than just reporting the dead end.
  Write a brief a fresh session could act on cold: the failure signature, what's established
  and how you know, what you ruled out and with what evidence, what to read first, and the
  numbered leads you'd have tried next. The groundwork is the expensive part, and a summary
  that omits it makes the next attempt redo it.
- Don't probe for `sudo` (`sudo -n true`) or tack a `sudo` fallback onto a larger command.
  A `sudo` anywhere in a compound command gets the *whole* call denied, so unrelated
  diagnostics bundled with it are lost too. If something genuinely needs privilege, say so
  and let me run it. A block on indirect `sudo` (a script that shells out to it) is usually
  telling you the script mixes privilege levels and the privileged step belongs elsewhere.
- After a change with observable runtime behavior, exercise it end-to-end yourself (drive the
  flow, endpoint, or render) to confirm it works, rather than asking the user to eyeball it.
- When a Bash command is expected to run long (servers, load tests, builds, sweeps), pass an
  explicit `timeout` so the default 2-minute cap doesn't kill it mid-run and orphan child
  processes.
- Tear down processes you started via the background-task mechanism through that same mechanism,
  not `pkill`: killing a harness-tracked task reports a spurious failure exit.
- Never `sleep` to wait for a backgrounded command. It re-invokes you when it exits, and its
  output file reads mid-flight with the Read tool, so sleeping blocks you for the full
  duration and learns nothing a Read wouldn't. Past the 10-minute Bash cap the sleep is
  killed having produced nothing at all. Start the work in the background, go do something
  else, and read the output file if you want progress before the notification arrives.
- When you start a server just to check something, assume I may already be running the app on
  the default port; pick a non-default port and clean it up when done.
- Reach past plain `grep` when a code search is structural rather than textual. `ast-grep`
  matches and rewrites by AST pattern (a bare `except`, a call with a literal argument) where
  regex can't. Run `--help` for the interface.
