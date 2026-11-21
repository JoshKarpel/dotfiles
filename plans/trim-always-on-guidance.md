# Compress and split the always-on guidance

Artifact: https://claude.ai/code/artifact/d72bc831-cded-4014-abec-11270c567955

This plan makes the global guidance in `claude/` smaller without breaking it
apart.
It keeps the way of thinking the guidance teaches in every session, moves out
the mechanics that only matter around a specific tool or file, and compresses
what stays.
It covers the global `CLAUDE.md` and the path-less rules in `claude/rules/`.
Splitting a single repo's `CLAUDE.md` is out of scope: dotfiles' own split is
earlier on this branch, and claude-scriptorium's needs the same thing in that
repo.

## What is wrong today?

Every session loads the global `CLAUDE.md` and every path-less rule, whatever
the session is for:

| Source | Chars |
|---|---|
| `claude/CLAUDE.md` | 13.8k |
| Path-less rules in `claude/rules/` | 107.3k |
| **Always-on global total** | **121.2k** |

Claude Code warns once a session's always-on instructions pass 150k
characters, so a project gets about 29k characters before it trips the warning:
exe-dev-atlas and counterweight, at about 23k each, are within 6k of it.

The warning is the visible symptom, and the cost is the real one.
The global layer's 121k characters are roughly 30k tokens, by a crude
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
So the roughly 30k tokens of global guidance are a cache write in every
session, and only later turns within a session read them cheaply.

## What are the goals, in order?

1. **The whole way of thinking is in every session.** The guidance is written
   in sections, but its purpose is to teach how I think, and I bring all of it
   to every problem.
2. **Every idea a correction taught stays.** Much of the text was added after a
   session got something wrong, which is the best evidence of what sessions
   rely on.
3. **The always-on set is the same in every session**, so the contract is
   predictable.
4. **Sessions don't pay for mechanics that don't apply to them**, and projects
   get headroom under the warning.

The first three outrank the fourth: a session missing part of the worldview
gives a worse answer, and the tokens are the price of not missing it.

The rules already work as a whole, and the cross-references show it.
`verify-empirically.md` calls itself "parse-don't-validate applied to your own
knowledge", and `error-handling.md` cites the same rule.
`durable-docs.md` cites the comments rule, and `public-record.md` cites the
secrets rule.
`control-plane.md` and `declarative.md` are written in `simple-vs-easy.md`'s
vocabulary.
Sorting rule by rule, by which sessions need each one, would leave a chat
session reading a rule that points at another it doesn't have.

That coupling is partly a matter of how the rules are written, not of what
they say, and [making each rule stand alone](#can-each-rule-stand-alone) loosens
it: the worldview stays whole in every session, and a later split no longer
breaks it.

## What separates worldview from mechanics?

**Worldview** is a principle or a way of judging: it holds across languages,
tools, and kinds of work, and it's often needed when nobody has framed the
situation as the one it covers.
"Suspect the check on a pass as well as a failure" is worldview.

**Mechanics** are facts about one tool, format, or platform: a flag, a config
knob, a gotcha.
They matter only when that tool is in play, which is usually when its file is
open.
"npm's `min-release-age` fails an exact pin inside the window with `ETARGET`"
is mechanics.

The test for a passage: would it still be true and useful if the tool it names
didn't exist?
Worldview passes it, even when it uses a tool as its example; mechanics fail it.
A third kind, **procedure**, is a checklist for a task someone names out loud,
such as an incident review.

Some mechanics are keyed to an action rather than a file: a shell loop that
makes Claude Code ask for approval, a `sleep` to wait on background work, an
unset `$TMPDIR` in a path.
A skill won't load for those, since nobody frames the moment as a task.
But the command text shows the action, so a `PreToolUse` hook matching it is
their scope, and its block message teaches at the moment it applies.
`claude-sleep-poll-check`, `claude-tmpdir-check`, `claude-uv-check`, and
`claude-avoid-approval-prompts` already work this way, which makes the global
`CLAUDE.md` bullets for the same cases a second copy of what their messages
say.

Each goes where its trigger is reliable:

- Worldview stays always-on, whole, and gets compressed.
- Mechanics move to a rule scoped to the files of the tool they're about.
  Where a scoped rule for that tool already exists, they join it.
- Procedure moves to a skill.
- Mechanics keyed to an action move to the message of a hook that recognizes
  it, and the always-on text keeps only the reason the message can't give.

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
- The always-on files arrive as one block: this session's transcript records
  them as a single `instructions` attachment of 32 files. Each sits under a
  header of about 130 characters (`Contents of <path> (user's private global
  instructions for all projects):`), in directory order rather than by name. A
  scoped rule arrives later, under the same header, as its own `nested_memory`
  attachment. No documented limit on the number of rule files turned up, and a
  probe with 300 extra one-line rules in a project's `.claude/rules/` delivered
  all 332 files in one `instructions` attachment, with no warning.
- A scoped rule loads only on a Read inside the project root. In a probe with
  hooks disabled, reading `tests/test_probe.py` in the project loaded a global
  rule scoped to test files (and `python.md`); reading a test file in the
  scratchpad loaded neither, with or without that directory passed through
  `--add-dir`. So a Read in another clone, or in a `git worktree add --detach`
  copy in the scratchpad, loads no scoped rule.
- Across this machine's transcripts, about two-thirds of the sessions that
  changed a test file had read one with Read first, so a rule scoped to test
  files would have loaded before the change. About a fifth started by writing
  a new test file without reading any, which loads nothing until a later Read.
- A skill's description sits in the skill listing in every session, and its
  body loads only when invoked. The listing has its own budget and truncates
  descriptions past it. The skills in `claude/skills/` already carry 14.3k
  characters of frontmatter, so each new skill adds a description that has to
  earn its place too.
- A skill or an always-on line can tell the model to read a rule file by path,
  so a scoped rule can also be reached from a task that opens no matching file.

A mechanic that misses its scope costs little: it's the kind of fact a `--help`,
a probe, or the tool's own error recovers.
That's why mechanics can take the reads-only gap, and worldview can't.

## How small can a slice be?

Since every file lands in the same block, file boundaries cost little: about
130 characters of header and a title apiece.
A file name matters only as an address, the name another rule cites ("the
verify-empirically rule"), and [standalone rules](#can-each-rule-stand-alone)
need fewer addresses.
So the unit of guidance can be as small as one idea, and the size of a file is
an editing choice, not a loading one.

That changes the two tiers differently:

- **Always-on**: splitting or merging files doesn't change what loads. Keep
  whatever boundaries make the text easy to edit and cite.
- **Scoped**: a smaller slice can take a narrower glob, so it loads in fewer
  sessions. Slice mechanics per tool or file format, not per topic: a Python
  mocking gotcha belongs with Python test files, not with all testing.

Two limits keep it from going to single sentences.
A slice should outweigh its header, which a two-line rule barely does.
And a narrower glob fires in fewer sessions, on top of the reads-only gap, so
the glob should match the files that are open when the mechanic matters,
not the narrowest pattern that names the tool.

## Where does each passage go?

### Mechanics that move to scoped rules

Each moves verbatim, as a whole bullet, sentence, or paragraph, so the move
changes no wording.

| Passage | From | To |
|---|---|---|
| The PEP 723 paragraph and its example | `supply-chain.md` | `python.md` (`**/*.py`, `bin/**`) |
| uv's `exclude-newer` and its per-package bypass | `supply-chain.md` | `pyproject.md` |
| mise's `minimum_release_age` and the pin that bypasses it | `supply-chain.md` | `mise.md` |
| npm's `min-release-age`, `ETARGET`, the exemption, and `npm audit fix` | `supply-chain.md` | new `npm.md` (`**/package.json`, `**/.npmrc`) |
| "Patch where the name is looked up" | `testing.md` | new `python-tests.md` |
| "Isolate a sandbox from the user's own config" | `testing.md` | new `test-sandboxes.md` |
| "Exclude a platform-only branch per platform" | `testing.md` | new `coverage.md` |
| The kubelet's `..data` symlink swap | `configuration.md` | `helm-crossplane.md` |

The new rules are scoped to the files open when each mechanic matters:

- `python-tests.md`: `**/test_*.py`, `**/*_test.py`, `**/conftest.py`, and
  `**/tests/**/*.py`, since patching is decided while writing a Python test.
- `test-sandboxes.md`: test files in any language (`**/test_*`, `**/*_test.*`,
  `**/*.test.*`, `**/tests/**`, `**/test/**`, `**/conftest.py`). A throwaway
  repo is built in a test of any kind, and no narrower file marks it.
- `coverage.md`: `**/.coveragerc`, `**/pyproject.toml`, and
  `.github/workflows/**`, where the exclusions and the per-platform gate are
  configured.

This repo's self-tests live inside `bin/` scripts that match none of the test
globs, so the repo's `.claude/rules/self-tests.md` points at
`test-sandboxes.md` by path.

`supply-chain.md` keeps its principles: fewer dependencies, pin and lock, one
installer per tool, floors not caps, how a resolver's model changes what a cap
costs, and cooldowns as a defense.
Its cooldown section keeps the duration and why, and loses the per-ecosystem
knobs.
`testing.md` keeps everything else, including `git checkout --` discarding a
whole file, since that's about how Claude undoes a deliberate break in any repo.

That's about 4.4k out of the always-on set.

### Procedure that moves to skills

- **An `operations` skill**, from `operations.md`'s "Alerts" and "Incident
  Follow-Up" sections, plus "Don't destroy evidence others are using". Adding an
  alert and writing an incident review are tasks someone names, which is when a
  skill's trigger is reliable. "Rollouts and Migrations" is worldview that
  shapes designs (make the safe intermediate state the steady state, run the
  new path beside the old), so it stays always-on as `rollouts.md`. About 1.6k
  out.
- **A `plan-page` skill**, from the global `CLAUDE.md`'s long bullet on
  publishing a plan's HTML page (about 1.8k): `plan-artifact`, the `Artifact:`
  line, and publishing with `force: true`. Writing or revising a plan is a named
  task, and plan mode names it outright. In a repo, the
  `claude-stop-plan-artifact` check catches a missed publish. Plan mode's file
  has no such check, so a miss there goes unnoticed until I look for the page;
  `CLAUDE.md` keeps one line saying every plan has a published page, which is
  what a session needs to recognize the task.

`designs.md` and `platforms.md` stay always-on.
Their questions (what does this proposal fix, what happens on partial failure,
who gets paged first) are how I judge any proposal, including one talked
through in chat, so a skill would be loading the worldview by the model's
judgment.

### Guidance about the harness, by path

`harness-context.md` (4.1k) governs where guidance goes, which only comes up
while editing Claude Code config or deciding to keep a lesson.
It gets `paths:` for `**/CLAUDE.md`, `**/AGENTS.md`, `**/.claude/**`, and
`claude/**`.
The global `CLAUDE.md`'s bullet on keeping lessons past a session names the
rule's path, so a session deciding where a lesson goes reads it first, and
`rule-curator`, `skill-creator`, and `hook-creator` read it by path too.

### Everything else stays always-on

All the remaining rules, including `testing.md`, `comments.md`,
`parse-dont-validate.md`, `locality-of-behavior.md`, `secrets.md`, and the
small code rules (`naming.md`, `functions.md`, `local-conventions.md`), stay
always-on and get compressed.
So does the global `CLAUDE.md`: guidance about this machine's own hooks and
harness has to be in context before the first tool call.
Its compression shrinks each bullet a hook enforces to what the hook's message
doesn't say, since the message arrives exactly when the bullet would have
mattered, at the cost of one blocked call.
Bullets with no hook behind them (bundling `sudo` into a compound command,
`pkill` on a harness-tracked task) stay, and are candidates for a hook after
this plan, each with its own self-tests.

## How is the compression guarded?

Moving fails in a way a transcript shows: the rule still loads somewhere, and
a harvest can find sessions that needed it and didn't load it.
Compressing fails without a trace: a cut idea is gone from every session, and
nothing records that it was doing any work.
So compression keeps ideas and spends words:

- **Protect what a correction added.** `git log -L` on a passage shows whether
  a `harvest-sessions` pass or a commit fixing an observed mistake added it, or
  whether it was written up front. A corrected passage keeps its claim and may
  be reworded tighter; it goes only when another rule says the same thing.
- **One statement per idea.** Within a rule, cut restatements, a second example
  making the same point, and framing that carries no claim. Keep the example a
  correction added, when there is one.
- **One home per idea across rules.** Where two rules say the same thing, the
  one that owns it keeps it, and the other keeps a clause of its own (see
  [the standalone test](#can-each-rule-stand-alone)) rather than the full
  statement. The known cases:
  `durable-docs.md`'s "Volatile Metrics" against the global `CLAUDE.md`,
  `verify-empirically.md`'s "run the control" against `testing.md`'s "suspect
  the check on a pass", `error-handling.md`'s "get the data off the request
  path" against `control-plane.md`'s "distribute results, not work", and the
  wrong-abstraction signal restated in `tradeoffs.md` and `platforms.md`.
- **Merge rules only where compression finds real overlap**, not by theme.
- **No percentage target.** A target pushes cuts into the passages this guard
  protects. My unreviewed guess is 10 to 20% of the always-on text; Phase 4
  measures what it was.
- **Replay known corrections for the largest rules.** For `writing.md`,
  `testing.md`, and `error-handling.md`, take two or three past prompts where
  the rule clearly changed the answer and run each through `claude -p` against
  the old and new text. It's noisy and costs a few runs, so it's limited to the
  rules where a lost idea would cost the most.

## Can each rule stand alone?

The always-on rules and the code rules carry about two dozen references to each
other, of four kinds, and each kind has its own fix:

| Kind | Example | Fix |
|---|---|---|
| A borrowed term | `control-plane.md` and `declarative.md` say "complecting", defined in `simple-vs-easy.md`; `tradeoffs.md` and `platforms.md` lean on making-changes' wrong-abstraction signal | Gloss the term in a clause where it's used ("complecting, braiding independent concerns together") |
| An analogy | `verify-empirically.md`: "parse-don't-validate applied to your own knowledge"; `configuration.md` says the same of config | Keep the idea as a clause of its own, or drop the analogy |
| A pointer for the action | `values-over-places.md`: "confirm empirically that nothing mutates it (see the verify-empirically rule)" | Keep, when the citing sentence already says what to do |
| A topic owner | `public-record.md`: "Secrets are the secrets rule's concern"; `configuration.md` deferring to "the secrets style guide" | Delete: it's maintenance guidance for whoever edits the corpus, which the repo `CLAUDE.md` already keeps out of rules |

The test for a rule: read alone, every sentence makes sense and can be acted on
without opening another rule.
A pointer can remain as somewhere to read more, as long as nothing in the
citing rule depends on it.

The fixes cost a clause here and there, which is a little duplication: a term
glossed in three rules is defined three times.
It buys two things.
A rule that stands alone can later be scoped, or moved to a skill, on the
evidence for that rule alone, without breaking the others.
And a rule read in isolation, as the scoped mechanics will be, still makes
sense.

The fixes go into each rule's compression pass, since both reword the same
text, and get the same guard.

## What does a session load afterwards?

These are estimates from character counts.
The skill listing loads in every session in every column, and isn't counted.

| Session | Today | After the splits | After compression |
|---|---|---|---|
| Chat or docs review | 121k | ~111k | lower, by what the guard leaves |
| Coding | 121k | ~111k, plus the mechanics its files scope in | the same, compressed |

The splits take about 10k out: 4.4k of mechanics, 1.6k and 1.8k into skills,
and 4.1k of harness guidance.
Headroom under the warning goes from about 29k to about 39k before compression.

## What does this cost?

- **Most of the token cost stays.** About 28k tokens of always-on text remain a
  cache write in every session until compression lands, and compression's size
  is unknown until it's done. Sorting rule by rule would save more, about 52k
  characters in a chat session, which is the price of keeping the worldview
  whole.
- **Splitting is per passage, not per file.** Each move is a judgment about one
  bullet or paragraph, so there are more of them to review, and a reader of
  `testing.md` no longer sees testing's tool gotchas in the same file.
- **A mechanic can miss its scope.** A session that reads only through Bash, or
  creates files with Write, never loads a scoped rule. Auto mode steers reads
  toward Bash, so this happens; it costs a rediscovered flag, not a worse
  judgment.
- **The new skills load by the model's judgment.** A `plan-page` miss in plan
  mode leaves a plan without its page until I notice.
- **Compression can still drop an idea written up front** that was doing work
  no harvest saw.
- **Problems surface in use, after merge.** Review catches a reworded rule that
  reads wrong, but not one whose loss shows only in some later session; the
  harvest after a few weeks of use, and ad-hoc fixes, are what catch those.

## What did I consider and reject?

- **Sorting rule by rule, by which sessions need each one**: the code-tier rules
  scoped to `**/*`, the design rules scoped to plan files with a
  `design-review` skill for the rest. It saves the most in chat and docs
  sessions, but it splits the worldview by what a session happened to read, and
  the always-on rules would cite rules that aren't loaded. Once the rules stand
  alone, it comes back as a per-rule question in Phase 5, decided on harvest
  evidence rather than up front.
- **A `design-review` skill** carrying `designs.md` and `platforms.md`. Those
  are how I judge any proposal, so they shouldn't wait on the model deciding a
  conversation is a design review. A skill carrying only a review procedure on
  top of the always-on doctrine stays an option if harvests show one missing.
- **Compressing to a percentage target**, which forces cuts into corrected
  passages.
- **Landing in stages**, with weeks of use between the splits and each batch of
  compression. It would make a regression easier to attribute, but every
  reworded rule gets reviewed anyway, and one commit per change keeps a
  regression traceable to its commit. Fixing forward costs less than the wait.
- **Merging the Hickey cluster** (simple-vs-easy, values-over-places,
  functional-core, declarative, locality-of-behavior) up front. It saves about
  1.5k of headings and references, and the cross-references already resolve by
  rule name. Compression merges where it finds real overlap.
- **Naming skills in `CLAUDE.md`.** The skill listing already loads every
  description in every session, so a pointer in `CLAUDE.md` is a second copy
  that drifts.
- **Moving the shell and repo mechanics out of the global `CLAUDE.md`.** Several
  govern Bash calls a session makes before reading any file, and several are
  how to work with this machine's own hooks.

## How does this land?

All of it lands on this branch, in this pull request, and problems get fixed
forward.
Josh reviews each reworded rule; a `harvest-sessions` pass after a few weeks of
use, and ad-hoc changes, catch what review doesn't.
One commit per move or per rule compressed, so each diff can be reviewed alone
and a regression traces to its commit.
The doctrine and the tools that build guidance change first, right after the
probes, so the moves and the compression follow the new approach, and so does
every session after merge that adds a rule, a skill, or a hook.
Moves change no wording; compression changes no destination.

### Phase 1: verify the loading mechanics

- [x] Confirm a global rule scoped to the test-file globs loads on the first Read
  of a matching file, using the session transcript (its `nested_memory`
  attachments) as the record, with hooks disabled.
- [x] Find whether it loads on a Read outside the project root (the scratchpad,
  another clone). It doesn't, even with `--add-dir`.
- [x] Load a few hundred small path-less rules, and confirm they all arrive in
  the `instructions` attachment, so slicing has no ceiling nearby.
- [x] Count, from recent transcripts, how often sessions that edit tests read a
  test file with the Read tool first.

### Phase 2: teach the doctrine and the guidance tools the new approach

- [ ] Rewrite `harness-context.md` around the worldview, mechanics, and
  procedure split: the always-on set teaches a way of thinking and is judged as
  a whole, each rule stands alone, a file boundary is cheap, conditional
  mechanisms carry mechanics and procedure, scoped rules load on reads only,
  and each mechanism's cost is counted in tokens times the sessions that load
  it, with caching measured rather than assumed.
- [ ] `rule-curator`: place new material by the worldview test, slice mechanics
  per tool with the glob of the files open when they matter, write each rule to
  stand alone, keep a correction's claim when editing, and read
  `harness-context.md` by path before deciding.
- [ ] `skill-creator`: correct what `paths:` does on a skill (it adds the
  description to the listing on a matching Read, and the body still waits for
  invocation), and say a skill carries procedure for a named task, never
  worldview, and can read a rule by path.
- [ ] `hook-creator`: read `harness-context.md` by path when deciding whether a
  hook is the mechanism.
- [ ] `harvest-sessions`: route a missing worldview idea to always-on, a missed
  mechanic to its scope, and an idea compression dropped back into its rule.
- [ ] `review-claude-config`: look for mechanics loading always-on, worldview
  scoped away, and rules that lean on another rule to make sense.
- [ ] Update the repo `CLAUDE.md`'s "Claude Code Rules" section to match.

### Phase 3: split without rewording

- [ ] Move the ecosystem settings out of `supply-chain.md`.
- [ ] Move the tool mechanics out of `testing.md` and `configuration.md`, and add
  `python-tests.md`, `test-sandboxes.md`, `coverage.md`, `npm.md`, and the
  self-tests rule's pointer.
- [ ] Create the `operations` skill, and rename what stays to `rollouts.md`.
- [ ] Create the `plan-page` skill from the global `CLAUDE.md`'s plan bullet.
- [ ] Scope `harness-context.md`, and point the global `CLAUDE.md` and the three
  curator skills at its path.

### Phase 4: compress, guarded

- [ ] Resolve the cross-rule duplicates listed above.
- [ ] For each always-on rule and the global `CLAUDE.md`, sort its passages by
  `git log -L` into those a correction added and those written up front, and
  compress under the guard, one commit per rule for Josh to review.
- [ ] In the same pass, make each rule stand alone: gloss borrowed terms, turn
  analogies into clauses or drop them, and delete topic-owner pointers.
- [ ] Shrink each global `CLAUDE.md` bullet a hook enforces to what the hook's
  message doesn't say, after reading the message.
- [ ] Replay two or three known corrections each for `writing.md`, `testing.md`,
  and `error-handling.md` against the old and new text.
- [ ] Count the always-on total again, and record what the splits and the
  compression each saved.

### Phase 5: after a few weeks of use

- [ ] Record from transcripts what a chat session and a coding session each
  loaded.
- [ ] Run a `harvest-sessions` pass. Its readers use `read_sessions.py --loads`
  to compare what loaded against what each session needed: a test edited
  without the test rules it needed, a plan written without the `plan-page`
  skill, an incident written up without the `operations` skill.
- [ ] Move back to always-on anything the harvest finds missing where it was
  needed, and restore any idea it finds compression dropped.
- [ ] For each rule that now stands alone, check the harvest for whether
  sessions that never read a matching file needed it. Scope it, or move it to a
  skill, only where they clearly didn't; otherwise it stays always-on.
