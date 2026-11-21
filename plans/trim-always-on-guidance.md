# Trim the always-on guidance

Artifact: https://claude.ai/code/artifact/d72bc831-cded-4014-abec-11270c567955

This plan sorts the global guidance in `claude/` by what should make each
piece load, then moves and trims it to match.
It covers the global `CLAUDE.md` and the path-less rules in `claude/rules/`.
Splitting a single repo's `CLAUDE.md` is out of scope: dotfiles' own split is
earlier on this branch, and claude-scriptorium's needs the same thing in that
repo.

## What is wrong today?

Every session loads the global `CLAUDE.md` and every path-less rule, whatever
the session is for:

| Source | Chars |
|---|---|
| `claude/CLAUDE.md` | 13.2k |
| Path-less rules in `claude/rules/` | 107.0k |
| **Always-on global total** | **120.2k** |

Claude Code warns once a session's always-on instructions pass 150k
characters, so a project gets about 30k characters before it trips the warning:
exe-dev-atlas and counterweight, at about 23k each, are within 7k of it.

The headroom is the visible symptom; the cost is the real one.
The global layer's 120k characters are roughly 30k tokens, by a crude
4-characters-per-token estimate, loaded at every session start and again by
every subagent that loads it.

### Does caching make always-on text cheap?

It would if the always-on text were shared across sessions, since a prefix
cached by one session is read cheaply by the next.
It isn't shared, measured from the first API call of recent sessions on this
machine (Claude Code 2.1.329):

| Sessions | Read from cache | Written to cache |
|---|---|---|
| Interactive Opus, across several repos | 33,996 tokens, every time | 48k to 67k tokens |
| `claude -p` Haiku probes, minutes apart, same directory | 13,194 tokens, every time | 50k to 53k tokens |

The cache read is the same in every session, so it's a fixed prefix shared
across all of them, and it ends before the instructions: the system prompt
carries per-session values (the scratchpad path, git status, the date) ahead
of the `CLAUDE.md` and rules text.
The roughly 30k tokens of global guidance land in each session's own cache
write.
So always-on text pays a cache write in every session, and a rule or skill
loaded mid-session pays the same write later, only in the sessions that load
it; within a session both are cache reads from then on.
Caching shrinks the per-turn cost of either one but doesn't favor always-on.

The sessions vary more than the guidance assumes.
A coding session needs the testing, comments, and dependency rules.
A docs review over an MCP connector reads no local file and writes no code,
but needs the design and prose doctrine, and loads the coding rules anyway.

## What are the goals, in order?

1. Doctrine is in context wherever it would change the answer.
2. Sessions don't pay for doctrine unlikely to apply to them.
3. The always-on set stays the same in every session, so the contract is
   predictable.

The first outranks the second: a session missing doctrine it needed costs a
wrong answer, while a session carrying doctrine it didn't need costs tokens.
The third gives way to the second, which is the change to the current
harness-context rule this plan makes.

When it's unclear whether a rule's trigger is reliable, it stays always-on.
A rule moves out only when the sessions that need it are clearly the ones that
will load it.

## How does each mechanism load?

These are what the plan builds on.

- A rule with `paths:` loads its body the first time a matching file is read.
  Reads only: creating a file with Write does not load it
  ([#93248](https://github.com/anthropics/claude-code/issues/93248), quoting the
  rules docs), and neither does a Bash `cat` or `sed`, nor Grep
  ([#90004](https://github.com/anthropics/claude-code/issues/90004),
  [#93403](https://github.com/anthropics/claude-code/issues/93403)). Edit
  requires a prior Read, so editing an existing file does load it. Observed in
  the session that wrote this plan: `markdown.md` and `shell.md` loaded on Read,
  never on the earlier Bash reads of the same files.
- A loaded rule arrives under a `Contents of <path>:` header, so the model sees
  each rule's file name as well as its headings.
- A session that only talks, or only reads through an MCP connector, loads no
  scoped rule at all.
- A skill's description sits in the skill listing in every session, and its
  body loads only when invoked. The listing has its own budget and truncates
  descriptions past it. The skills in `claude/skills/` already carry 14.3k
  characters of frontmatter, so each new skill adds a description that has to
  earn its place too.
- A skill with `paths:` is not loaded by its glob. Its description joins the
  listing (a mid-session `skill_listing` delta) when a matching file is read,
  and its body still waits for the model to invoke it. Observed with a probe
  skill in a scratch repo: the description arrived after the matching Read, the
  body never did.
- A skill can tell the model to read a file by path, including a rule file.
  So one rule file can load by glob in a coding session and through a skill in
  a docs review, with no second copy.

Nothing loads one body both ways, by a glob and by invocation. The rule-plus-
wrapper-skill pairing above is the nearest thing that exists today.

## Where does each rule go?

Each rule goes to one of four places, sorted by what triggers the need for it.

### Always-on: doctrine needed when nobody is thinking about it

These apply in chat replies, docs reviews, and code alike, and are needed
precisely when the session hasn't framed the situation as the one they cover.
They stay always-on and get trimmed.

| Rule | Chars | Why it stays always-on |
|---|---|---|
| `writing.md` | 7.8k | Every reply is prose |
| `error-handling.md` | 7.2k | Fallback is chosen without being named |
| `tradeoffs.md` | 5.2k | Every recommendation is a choice on an axis |
| `durable-docs.md` | 4.9k | Docs reviews are prose about the present state |
| `making-changes.md`, less its refactoring half | ~4.7k | Abstraction choices happen in designs and code |
| `verify-empirically.md` | 4.3k | Any session can state a remembered fact |
| `api-design.md` | 3.9k | An endpoint gets designed while coding, unframed |
| `supply-chain.md`, less its ecosystem settings | ~3.0k | A dependency gets added at `cargo add`, before any file is read |
| `declarative.md` | 2.7k | Applies to designs as much as to code |
| `public-record.md` | 2.4k | Anything can end up in a commit or issue |
| `blameless.md` | 2.3k | Any write-up can assign fault |
| `simple-vs-easy.md` | 1.8k | Cited by the others as the base vocabulary |
| `control-plane.md` | 1.8k | Applies to designs as much as to code |
| `values-over-places.md` | 1.7k | Applies to designs as much as to code |
| `functional-core.md` | 1.2k | Applies to designs as much as to code |

That's about 54.9k after the two splits.
They get a narrow trim in a later pull request, with no percentage target; see
[how the trim is guarded](#how-is-the-trim-guarded).

`making-changes.md` splits along the wrong-abstraction line. "Make the Change
Easy", "Don't Factor Ahead of the Evidence", "Duplication Is Cheaper Than the
Wrong Abstraction", "Read Clustered Review Findings as One Finding", and "Slice
Thin, End to End" are about how to shape a change, in a design as much as in
code, and stay. "Keep Refactors Small" and "Chesterton's Fence" are about
editing code that exists, and move to a code-tier `refactoring.md` (about
1.4k).

`supply-chain.md` keeps its principles (fewer dependencies, pin and lock,
floors not caps, cooldowns) and moves each ecosystem's settings to the scoped
rule that already governs that file:
uv's `exclude-newer` and the PEP 723 example to `pyproject.md`,
mise's `minimum_release_age` to `mise.md`,
and npm's `min-release-age` to a new rule scoped to `package.json` and `.npmrc`.

### Scoped to any file: doctrine for writing code

These matter when code or config is being written, which usually starts by
reading the code around it.
They get `paths: ["**/*"]`, so they're free in docs and chat sessions and load
at the first Read in a coding one.
A session that reads only through Bash and creates only new files never loads
them; see the costs.

| Rule | Chars |
|---|---|
| `testing.md` | 9.6k |
| `comments.md` | 5.2k |
| `configuration.md` | 2.6k |
| `locality-of-behavior.md` | 2.4k |
| `parse-dont-validate.md` | 1.8k |
| `refactoring.md` (new, from `making-changes.md`) | ~1.4k |
| `dependency-injection.md` | 1.1k |
| `naming.md` | 0.6k |
| `local-conventions.md` | 0.3k |
| `functions.md` | 0.2k |

That's about 25.2k, loaded only in sessions that read files.

### Design doctrine: by path for plans, by skill for everything else

`designs.md` and `platforms.md` (12.4k) apply when writing or reviewing a
design. Two triggers cover that:

- **A path scope on the plan and design files themselves**: `**/plans/**`,
  `**/*plan*.md`, `**/*design*.md`, `**/rfcs/**`, and `**/adr*/**`. A session
  that reads a plan is very likely reviewing or revising one, and this loads the
  doctrine without asking the model to recognize that. A plan written fresh
  with Write doesn't trigger it, since scopes fire on reads only.
- **A `design-review` skill** for the cases with no local file: a design doc
  reviewed over an MCP connector, a design talked through in chat, a new plan.
  Its body is a pointer: read `designs.md` and `platforms.md` by path, and
  `secrets.md` when the design handles credentials.

`operations.md` (3.0k) becomes an `operations` skill: rollouts, migrations,
alerts, and incident follow-up, all named tasks.

### Scoped to the files they govern

| Rule | Chars | Scope |
|---|---|---|
| `harness-context.md` | 4.1k | `**/CLAUDE.md`, `**/AGENTS.md`, `**/.claude/**`, `claude/**` |
| `secrets.md` | 3.7k | Helm and Kubernetes manifests, `Dockerfile`, `.github/workflows/**`, `**/.env*`, `**/*.tf` |
| `rfc2119.md` | 0.8k | `**/*.md` |

`secrets.md`'s code-side half (wrap secrets in a redacting type) is already in
`python.md`.
`rule-curator`, `skill-creator`, and `hook-creator` read `harness-context.md` by
path, since they're the tasks that decide where guidance goes.

### The global `CLAUDE.md`

Everything stays. Guidance about working with this machine's own hooks and
harness has to be in context before the first tool call, and much of "How to
Work" is that: the scratchpad path (`claude-tmpdir-check`), `uv run`
(`claude-uv-check`), `sleep` (`claude-sleep-poll-check`), loops and `$(...)`
(`claude-avoid-approval-prompts`), `sudo`, and the plan page
(`claude-stop-plan-artifact`).
It gets the same guarded trim as the always-on rules, in the same later pull
request.

## How is the trim guarded?

Moving and trimming fail differently.
A moved rule still exists and still loads somewhere; the failure is a session
that needed it and didn't load it, and the transcript records which rules
loaded, so a harvest can find those sessions.
A trimmed sentence is gone from every session, and nothing records that it was
doing any work.
That's where reliance I don't know about would be lost, so the trim is the
step that needs the guard.

It's also the smaller saving.
Moves alone take a chat session from 120k to about 68k; the trim takes about
18k more (roughly 4.5k tokens) off every session.

The evidence of reliance is in the history.
Much of the always-on text was added by `harvest-sessions` passes, each from a
correction Claude needed in a real session, so `git log -L` on a passage shows
whether it was added after an observed failure or written up front.
The guard follows from that:

- **Protect what a correction added.** A passage added by a harvest, or by a
  commit fixing an observed mistake, stays unless it duplicates another rule.
  It may be reworded, keeping its claim.
- **Cut only from text written up front**, and only where it's plainly
  redundant: restated elsewhere, a second example making the same point, or
  framing that carries no claim.
- **No percentage target.** A target pushes the cut into exactly the text this
  guard protects.
- **Replay known corrections for the largest rules.** For `writing.md`,
  `error-handling.md`, and `testing.md`, take two or three past prompts where
  the rule clearly changed the answer and run each through `claude -p` against
  the old and new text. It's noisy and costs a few runs, which is why it's
  limited to the rules where a lost sentence would cost the most.

## What does a session load afterwards?

These are estimates from character counts, before any trim.
The skill listing loads in every session in every column, and isn't counted.

| Session | Today (chars) | After the moves (chars) |
|---|---|---|
| Chat or docs review | 120k | ~68k always-on |
| Design review | 120k | ~68k, plus ~12k design doctrine |
| Coding | 120k | ~68k, plus ~25k on the first Read |

The 68k is the always-on rules after the two splits (~55k) and the global
`CLAUDE.md` (~13k).
The guarded trim lowers it, by an amount the guard decides rather than a
target.

## What does this cost?

- A conversation about how to structure code, with no file opened, lacks the
  coding doctrine until something is read. The design-review skill covers
  the case that's framed as a design; the unframed one goes uncovered.
- A coding session that reads only through Bash gets the scoped rules at its
  first Edit, which needs a Read first. One that only creates new files with
  Write never gets them at all. Auto mode steers reads toward Bash, so this is
  not a corner case; Phase 1 measures how often coding sessions here use Read.
- A skill loads only when its description matches, which is the model's call.
  The design-review and operations triggers are named tasks, which is the
  case where that call is reliable; a design question asked in passing may
  not trigger it.
- The always-on set is no longer the whole contract. A session's guidance now
  depends on what it read, so a behavior seen in one session can be absent
  from another for that reason alone.
- More files and more indirection: a rule read by both a glob and a skill has
  two ways in, and renaming it means updating the skill too.
- A trimmed sentence I relied on without knowing it is lost without a trace.
  The guard protects what a correction added, but text written up front can
  still have been doing work no harvest saw.
- Landing in stages takes weeks rather than one review, and the savings arrive
  in steps.

## What did I consider and reject?

- **Merging the Hickey cluster** (simple-vs-easy, values-over-places,
  functional-core, declarative, locality-of-behavior) into one file up front.
  The cross-references would survive it, since they resolve by rule name and
  heading and the model sees both, but the saving is about 1.5k of headings
  and references. Phase 4 merges wherever trimming turns up real overlap,
  rather than merging by theme in advance.
- **Naming skills in `CLAUDE.md`.** The skill listing already loads every
  description in every session; a pointer in `CLAUDE.md` is a second copy of
  it that drifts.
- **Moving the shell and repo mechanics out of the global `CLAUDE.md`** into a
  scoped rule. Several govern Bash calls a session makes before reading any
  file, and several are how to work with this machine's own hooks.
- **A `UserPromptSubmit` hook that injects a skill** when a prompt carries a docs
  link. It would make the design-review trigger structural rather than the
  model's call, at the price of a hook that guesses intent from URLs. Worth
  revisiting if the skill misses in practice.
- **A hook that loads scoped rules on every file operation**, Write and Bash
  included, closing the reads-only gap. It would match tool input against each
  rule's `paths:` and inject the body once per session. It reimplements Claude
  Code's own loader beside it, and a Bash command's file arguments are a parse
  of shell text, so it's held until Phase 1 shows the gap matters.
- **One mechanism that loads a body both by a glob and by invocation.** That's
  the right shape, and it doesn't exist; it would be a Claude Code feature
  (for instance a skill option that injects the body when `paths:` matches,
  instead of only listing the skill). The wrapper skill that reads a rule file
  by path is the nearest approximation, and it's what this plan uses.
- **Scoping only, without trimming.** Scoping saves only in sessions that don't
  read the scope; trimming saves in all of them, so the always-on tier gets
  both, with the trim guarded and landed after the moves have been used.
- **A trim to a percentage target** (25 to 30% of the always-on tier). It
  saves more, but it forces cuts into the passages corrections added, which are
  the best evidence of what sessions rely on.
- **Everything in one pull request.** About twenty changes landing at once
  would leave a regression that couldn't be traced to any one of them.

## How does this land?

In stages, so a regression can be traced to the change that caused it.
The verification, the doctrine rewrite, and the moves land on this branch, in
this pull request.
The trims land in later pull requests, after the moves have been used for a few
weeks and a harvest has checked them.
One commit per move or per rule trimmed, so each diff can be reviewed alone.
Moves change no wording; trims change no destination.

### Phase 1: verify the loading mechanics

- [ ] Confirm a global rule with `paths: ["**/*"]` loads on the first Read in a
  project, using the session transcript (its `nested_memory` attachments) as the
  record, with hooks disabled.
- [ ] Find whether it loads on a Read outside the project root (the scratchpad,
  another clone, plan mode's plan file).
- [ ] Confirm an MCP-only session loads none.
- [ ] Count, from recent transcripts, how many coding sessions here read a file
  with the Read tool before writing code, which is how many would get the code
  tier at all.

### Phase 2: rewrite the doctrine this replaces

- [ ] Rewrite `harness-context.md` around the ranking above: always-on for
  doctrine needed when the situation isn't framed, a file scope for doctrine
  tied to reading a kind of file, a skill for doctrine tied to a named task,
  always-on whenever the trigger is in doubt, and the cost of each counted in
  tokens times the sessions that load it, with caching measured rather than
  assumed.
- [ ] Update the repo `CLAUDE.md`'s "Claude Code Rules" section to match.

### Phase 3: move without rewording

- [ ] Split `refactoring.md` out of `making-changes.md`.
- [ ] Move the ecosystem settings out of `supply-chain.md`.
- [ ] Scope the code tier to `**/*`.
- [ ] Scope `designs.md` and `platforms.md` to plan and design files, and add
  the `design-review` skill that points at them.
- [ ] Create the `operations` skill from `operations.md`.
- [ ] Scope `harness-context.md`, `secrets.md`, and `rfc2119.md`.

### Phase 4: measure the moves

- [ ] Count the always-on total again, and record from transcripts what a chat
  session, a design review, and a coding session each loaded.
- [ ] After a few weeks of use, run a `harvest-sessions` pass. Its readers use
  `read_sessions.py --loads` to compare what loaded against what each session
  needed: sessions that edited code without the code tier, discussed a design
  without `designs.md`, or ran a rollout without the `operations` skill.
- [ ] Move back to always-on any rule the harvest finds missing where it was
  needed, before any trim starts.

### Phase 5: trim, guarded, in later pull requests

- [ ] Deduplicate `durable-docs.md`'s "Volatile Metrics" against the global
  `CLAUDE.md` bullet, and `verify-empirically.md`'s "run the control" against
  `testing.md`'s "suspect the check on a pass".
- [ ] For each always-on rule and the global `CLAUDE.md`, sort its passages by
  `git log -L` into those a correction added and those written up front, and
  cut only redundant text from the second group.
- [ ] Replay two or three known corrections each for `writing.md`,
  `error-handling.md`, and `testing.md` against the old and new text.
- [ ] Land the trims a few rules per pull request, with use between them, each
  for Josh to review, merging rules where the trim turns up overlap.
