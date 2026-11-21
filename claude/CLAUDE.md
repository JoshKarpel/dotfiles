# CLAUDE.md

## Communication

- Be concise and direct; skip preamble and flattery.
- When a request is ambiguous in a way that changes the outcome, ask rather than assume.
- A terse follow-up ("does it check for X?", "which mount is it at now?") is about what I
  was last talking about, which isn't always what you last answered. When your reading of
  one is about to start work (a diagnosis, a search, a design change), say the reading in
  a line first ("Reading this as ship-pr, not git land: ..."), so a wrong guess costs a
  sentence rather than a turn.
- Avoid em dashes; use commas, parentheses, colons, or separate sentences instead.
- Use the Oxford comma: "red, white, and blue", not "red, white and blue".
- Don't cite volatile exact metrics (test counts, file counts, coverage percentages) in
  summaries or replies; they go stale on the next change. Say "tests pass" or "mypy clean",
  not "238 tests across 68 files".

## Committing and Landing

This is a durable authorization: you don't need to ask before any of it, and approval
doesn't need repeating per session.

- Commit on any branch but the default without waiting to be asked, once pre-commit
  passes. The `claude-git-commit-check` hook refuses a commit on the default branch or a
  detached `HEAD`, and `--no-verify`.
- Commit at the end of each turn that changed files, unless the turn ends on a question
  or an offer to me. The `claude-stop-commit` check asks for it once pre-commit has
  passed; write a message describing the step.
- Bring a branch up to date by merging the base branch in, never by rebasing, and don't
  amend a commit that has been pushed, unless I ask for it explicitly. `git land` never
  force-pushes, so pushing a rewritten branch is mine.
- Once the change is worth showing (a coherent first version whose checks pass locally),
  write the PR draft to the path `git land --path` prints, and run `git land`. The draft
  is shaped like a commit message: the title, a blank line, then the body. Put what you
  wrote (the problem, the change, how it was checked) inside a `<details>` fold whose
  `<summary>` names your model, such as `<summary>Claude Opus 5.5</summary>`. Leave out
  the effort level: you can't see it, so a stated one is a guess. After that, land again at the end of
  each turn that committed, so the PR and its CI stay current.
- When the work resolves a GitHub issue, link it from the draft with a closing keyword
  on a line of its own above the fold (`Closes #12`), so the PR appears in the issue's
  Development sidebar and merging closes it
  ([linking a pull request to an issue](https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/linking-a-pull-request-to-an-issue)).
  Use the issue I named when starting the session; when I named none, search the repo's
  open issues for one, link it only if it clearly describes this work, and otherwise
  name the near misses in the report. Work that only advances an issue mentions it
  without a keyword (`Part of #12`), since a keyword closes the issue on merge. Link
  only issues the repo's readers can see (the public-record rule).
- Rewrite the draft whenever what the PR is has changed. It is the only way to change your
  part of the PR description; the next land carries it.
- After landing, wait for the PR's checks with `claude-wait-checks` in the background,
  which re-invokes you when it exits, and do what its last lines say. It gives up after
  15 minutes so no wait outlives the prompt cache: when it times out, look at the runs
  still going for anything anomalous before starting it again. It also exits as soon as
  waiting can't help, most often for a PR with merge conflicts, whose `pull_request`
  checks GitHub never runs: resolve those with the resolve-conflicts skill, land, and
  wait again. Don't wait with a bare `gh pr checks --watch`, which has no deadline and
  can't tell a conflicted PR from a slow one.
- Push only through `git land`. When it refuses over workflow files, run
  `git land --workflows` straight away rather than asking in text first: that run
  prompts me for permission, and the prompt is where I approve it. Never open or edit a pull request directly, merge, approve, enable auto-merge, or
  publish a release, even when I ask in the moment: say that I have to, and stop.
- When a guard or a land refusal blocks something, say so and stop. Don't look for another
  route to the same effect.
- Committing and landing are what put text in the record: a land publishes the commits
  and the PR description at once. So when unsure whether something belongs there, ask
  before committing (the public-record rule).

## The Stop Sequence

- After a turn that changed files in the session's repo (the scratchpad and other clones
  don't count), `claude-stop` runs checks (pre-commit, the finishing pass, the plan page,
  the commit, the land), and the last of them asks for the turn's report. End the work
  with one line and hold the report; keep replies to checks short; write the report
  when asked.
- When a reply ends on a question or an offer to me, put the report in that same reply,
  with the question last. As the turn tries to stop, a small model reads each reply that
  contains a `?`, and one that ends by asking me something ends the turn on the spot: no
  later check runs, so nothing will ask for the report, and the commit and the land wait
  for the next turn. A reply to a check counts too: if pre-commit flags something you'd
  rather ask me about than fix (whether to suppress a lint, say), that reply is the
  report followed by the question.
- A reply that asks me something must contain a `?`, so phrase an offer as a question:
  "Want me to also update the docs?", never "Let me know if you want the docs updated."
  A reply with no `?` anywhere is never read as asking, so the checks run over it and
  bury the question.
- Make that question unmistakable: one direct question or offer, at the end. Don't close
  with one out of habit: a turn that ends on an offer leaves its work uncommitted and
  unlanded until I reply.
- In a turn that changed nothing in the session's repo, such as a discussion, answer
  normally: no check fires, so a held report would never arrive.

## How to Work

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
- Clone a GitHub repo with `gh repo clone <owner>/<repo>`, not `git clone`. For a fork it
  adds the parent as an `upstream` remote, which is where `git new` and
  `manage-worktrees new` start branches (`git base-remote` says which remote), so
  a pull request back to the parent doesn't carry the fork's lag. A fork cloned
  some other way needs `git remote add upstream <parent-url>` before branching.
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
- Read another clone, or another revision, without moving it: `git show <rev>:<path>`,
  `git grep <pattern> <rev>`, or `git worktree add --detach` into the scratchpad. A
  `git checkout` in a clone outside the session's repo switches what my editor, my other
  sessions, and that clone's own tests are looking at, and nothing tells them it moved.
  The same goes for global state changed to get a check passing: `mise use -g` or any
  edit under `~/.config` writes through a symlink into the dotfiles clone, as an
  uncommitted change on whatever branch that clone has checked out.
- When you start a server just to check something, assume I may already be running the app on
  the default port; pick a non-default port and clean it up when done.
- Every markdown plan (plan mode's, or a plan doc in a repo) has a published HTML Artifact,
  rendered by `plan-artifact <plan.md> <out.html>` and never written or edited by hand: the
  page is derived from the `.md` each time, so any later session just reruns the script.
  Read `plan-artifact --help` before writing or revising a plan: the page renders more than
  plain markdown (GFM alerts and footnotes, mermaid, raw HTML and `<svg>`, and a `<figure>`
  with its own scoped style and script for an interactive diagram), and diagrams belong in
  the plan itself so it stays one self-contained file. Sessions don't remember
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
