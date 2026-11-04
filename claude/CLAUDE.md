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
  is worth keeping past this one, put it in a committed artifact (the harness-context
  rule says which mechanism), and ask where it belongs when that isn't obvious, rather
  than dropping it in the nearest file.
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
- In a uv project, Python is `uv run python`, heredocs and one-liners included.
- Spell the scratchpad path out literally in every command rather than through a variable.
  Shell state doesn't persist between calls, `$TMPDIR` may be unset (it is on exe.dev), so
  `$TMPDIR/x` lands at `/x`, and Claude Code refuses an `rm` whose target is a variable.
  Don't silence a backup copy with `2>/dev/null || true`: a backup that never happened
  turns the restore into a lie.
- A `for`/`while` loop or a `$(...)` substitution makes Claude Code ask me to approve a
  Bash call even when every command in it is read-only. Reach for the tool's own
  multi-file form instead when it has one: `head -n 40 a b c` prints a `==> a <==`
  header per file, `grep -n pat a b c` (or `grep -rn pat dir`) prefixes each match with
  its file, and `wc -l a b c` counts each. For a substitution, run the inner command in a
  call of its own and use its output literally in the next.
- When you start a server just to check something, assume I may already be running the app on
  the default port; pick a non-default port and clean it up when done.
- Every markdown plan (plan mode's, or a plan doc in a repo) has a published HTML Artifact,
  rendered by `plan-artifact <plan.md> <out.html>` and never written or edited by hand: the
  page is derived from the `.md` each time, so any later session just reruns the script.
  Read `plan-artifact --help` before writing or revising a plan: the page renders more than
  plain markdown (GFM alerts and footnotes, mermaid, raw HTML and `<svg>`), and diagrams
  belong in the plan itself so it stays one self-contained file. Sessions don't remember
  artifacts, so the file carries the link: an `Artifact: <url>` line directly under the `# Title`. If the line is there, update that
  artifact (`url`) rather than publishing a new one; if not, publish and add the line.
  Publish to an existing plan page with `force: true`, without reading it first: I
  authorize discarding whatever version is live, every time. The `.md` is the source, so
  the live page is only an earlier render, often another session's, with nothing to
  merge, and reading it pulls the whole page into context for nothing.
  In a repo, the `claude-stop-plan-artifact` stop check asks for the republish once a
  turn's edits have settled, but only the first time per plan in a session: after that,
  republish at the end of any turn that changed the plan, not after every edit. Plan mode's
  file lives outside any repo, so publish that one yourself when you write or revise it.
  Who can see a plan page is mine to set in claude.ai, and sharing one with my org is
  deliberate: don't flag it, ask about it, or narrow it. The link is fine to commit even in
  a public repo, since opening it still takes whatever access I've granted.
- Reach past plain `grep` when a code search is structural rather than textual. `ast-grep`
  matches and rewrites by AST pattern (a bare `except`, a call with a literal argument) where
  regex can't. Run `--help` for the interface.
