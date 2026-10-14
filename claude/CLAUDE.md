# CLAUDE.md

## Communication

- Be concise and direct; skip preamble and flattery.
- When a request is ambiguous in a way that changes the outcome, ask rather than assume.
- Avoid em dashes; use commas, parentheses, colons, or separate sentences instead.
- Don't cite volatile exact metrics (test counts, file counts, coverage percentages) in
  summaries or replies; they go stale on the next change. Say "tests pass" or "mypy clean",
  not "238 tests across 68 files".

## How to Work

- Don't create git commits or push changes on my behalf. The one exception is completing
  a merge that needs no judgment: a fast-forward, or a merge commit for a merge git applied
  without conflicts, is fine. A merge whose conflicts you resolved stays uncommitted for
  me to review, and pushing is never yours to do.
- Auto-memory is off, so nothing persists automatically between sessions. When something
  is worth keeping past this one, put it in a committed artifact: a rule in
  `claude/rules/` for portable doctrine, `CLAUDE.md` for how-to-work-with-me guidance, a
  skill for a procedure, a hook for something the harness should enforce. Ask where it
  belongs when that isn't obvious, rather than dropping it in the nearest file.
- Context that belongs in every session but is only true at a point in time wants a
  `SessionStart` hook that computes it, not a hand-maintained list that drifts. Repo
  state, available recipes, the current toolchain version: derive it at startup so it
  can't go stale.
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
- Read a file with the Read tool (`offset`/`limit` for a range), never `sed -n`, `head`, or
  `tail` on the file, whatever a harness hint suggests. Path-scoped rules and nested
  `CLAUDE.md` files load only when a file tool touches a path, so a shell read skips them.
  Trim a pipe with `head`/`tail`. In a uv project, Python is `uv run python`, heredocs and
  one-liners included.
- Spell the scratchpad path out literally in every command rather than through a variable.
  Shell state doesn't persist between calls, `$TMPDIR` may be unset (it is on exe.dev), so
  `$TMPDIR/x` lands at `/x`, and Claude Code refuses an `rm` whose target is a variable.
  Don't silence a backup copy with `2>/dev/null || true`: a backup that never happened
  turns the restore into a lie.
- When you start a server just to check something, assume I may already be running the app on
  the default port; pick a non-default port and clean it up when done.
- Whenever you write or edit a markdown plan file (plan mode's, or a plan doc in a repo),
  publish an HTML Artifact of it in the same turn. Design the page rather than transcribing
  the markdown: present the plan the way you would if I'd asked for it as an artifact, with
  whatever layout, navigation, diagrams, or interactive pieces serve this plan. The `.md`
  stays the source of truth, so rebuild the page from it on every change, carrying the
  plan's substance without adding or dropping any.
  Sessions don't remember artifacts, so the file carries the link: an `Artifact: <url>` line
  directly under the `# Title`. If the line is there, update that artifact (`url`) rather
  than publishing a new one; if not, publish, then add the line. The artifact is private,
  so the link is fine to commit even in a public repo.
- Reach past plain `grep` when a code search is structural rather than textual. `ast-grep`
  matches and rewrites by AST pattern (a bare `except`, a call with a literal argument) where
  regex can't. Run `--help` for the interface.
