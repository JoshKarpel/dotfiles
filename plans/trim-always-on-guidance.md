# Trim the always-on guidance

Artifact: https://claude.ai/code/artifact/d72bc831-cded-4014-abec-11270c567955

This plan sorts the global guidance in `claude/` by what should make each
piece load, then moves and trims it to match.
It covers the global `CLAUDE.md` and the path-less rules in `claude/rules/`.
Splitting a single repo's `CLAUDE.md` is out of scope: dotfiles' own split is
[#113](https://github.com/JoshKarpel/dotfiles/pull/113), and claude-scriptorium's
needs the same thing in that repo.

## What is wrong today?

Every session loads the global `CLAUDE.md` and every path-less rule, whatever
the session is for:

| Source | Chars |
|---|---|
| `claude/CLAUDE.md` | 13.2k |
| Path-less rules in `claude/rules/` | 107.0k |
| **Always-on global total** | **120.2k** |

Claude Code warns once a session's always-on instructions pass 150k
characters, so a project gets about 30k before it trips the warning:
exe-dev-atlas and counterweight, at about 23k each, are within 7k of it.

The headroom is the visible symptom; the cost is the real one.
By a crude 4-characters-per-token estimate, the global layer is about 30k
tokens at every session start, paid again by every subagent that loads it.
Prompt caching makes the per-turn cost a cache read rather than full input,
which shrinks it without removing it.
The measure that matters is tokens loaded times the sessions that load them,
and much of today's always-on text applies in only some of those sessions.

The sessions vary more than the guidance assumes.
A coding session needs the testing, comments, and dependency rules.
A docs review over an MCP connector reads no local file and writes no code,
but needs the design and prose doctrine, and loads the coding rules anyway.

## What are the goals, in order?

1. Doctrine is in context wherever it would change the answer.
2. Sessions don't pay for doctrine that can't apply to them.
3. The always-on set stays the same in every session, so the contract is
   predictable.

The first outranks the second: a session missing doctrine it needed costs a
wrong answer, while a session carrying doctrine it didn't need costs tokens.
The third gives way to the second, which is the change to the current
harness-context rule this plan makes.

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
  a design review, with no second copy.

Nothing loads one body both ways, by a glob and by invocation. The rule-plus-
wrapper-skill pairing above is the nearest thing that exists today.

## Where does each rule go?

Each rule goes to one of four places, sorted by what triggers the need for it.

### Always-on: doctrine needed when nobody is thinking about it

These apply in chat replies, docs reviews, and code alike, and are needed
precisely when the session hasn't framed the situation as the one they cover.
They stay always-on and get trimmed.

| Rule | Chars | Why it can't be conditional |
|---|---|---|
| `writing.md` | 7.8k | Every reply is prose |
| `error-handling.md` | 7.2k | Fallback is chosen without being named |
| `making-changes.md` | 6.1k | Abstraction choices happen in designs and code |
| `tradeoffs.md` | 5.2k | Every recommendation is a choice on an axis |
| `durable-docs.md` | 4.9k | Docs reviews are prose about the present state |
| `verify-empirically.md` | 4.3k | Any session can state a remembered fact |
| `public-record.md` | 2.4k | Anything can end up in a commit or issue |
| `blameless.md` | 2.3k | Any write-up can assign fault |
| `simple-vs-easy.md` | 1.8k | Cited by the others as the base vocabulary |

That's 42.0k now. Trimming targets 25 to 30%, to about 30k.

### Scoped to any file: doctrine for writing code

These matter when code or config is being written, which usually starts by
reading the code around it.
They get `paths: ["**/*"]`, so they're free in docs and chat sessions and load
at the first Read in a coding one.
A session that reads only through Bash and creates only new files never loads
them; see the costs.

| Rule | Chars | Note |
|---|---|---|
| `testing.md` | 9.6k | |
| `supply-chain.md` | 6.0k | Ecosystem settings move to their own rules (below) |
| `comments.md` | 5.2k | |
| `api-design.md` | 3.9k | Also read by the design-review skill |
| `declarative.md` | 2.7k | Also read by the design-review skill |
| `configuration.md` | 2.6k | |
| `locality-of-behavior.md` | 2.4k | |
| `parse-dont-validate.md` | 1.8k | |
| `control-plane.md` | 1.8k | Also read by the design-review skill |
| `values-over-places.md` | 1.7k | Also read by the design-review skill |
| `functional-core.md` | 1.2k | Also read by the design-review skill |
| `dependency-injection.md` | 1.1k | |
| `naming.md` | 0.6k | |
| `local-conventions.md` | 0.3k | |
| `functions.md` | 0.2k | |

That's 41.1k, loaded only in sessions that touch files.

`supply-chain.md` keeps its principles (fewer dependencies, pin and lock,
floors not caps, cooldowns) and moves each ecosystem's settings to the scoped
rule that already governs that file:
uv's `exclude-newer` and the PEP 723 example to `pyproject.md`,
mise's `minimum_release_age` to `mise.md`,
and npm's `min-release-age` to a new rule scoped to `package.json` and `.npmrc`.

### Skills: doctrine for a task someone names

Reviewing a design, planning a migration, and writing a postmortem are tasks
the user names out loud, which is the case the harness-context rule already
grants skills: nothing has to be recognized in advance.

- **`design-review`**, carrying `designs.md` and `platforms.md` (12.4k) as its
  own body. It tells the model to read `api-design.md`, `declarative.md`,
  `control-plane.md`, `values-over-places.md`, `functional-core.md`, and
  `secrets.md` by path when the design touches what they cover, so a
  design review gets them without a copy.
- **`operations`**, carrying `operations.md` (3.0k): rollouts, migrations,
  alerts, and incident follow-up.

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

| Section | Chars | Destination |
|---|---|---|
| Communication | 0.9k | Stays |
| Committing and Landing | 3.4k | Stays, trimmed |
| The Stop Sequence | 1.6k | Stays, trimmed |
| How to Work: the plan-page bullet | 2.3k | A `write-plan` skill; `claude-stop-plan-artifact` already enforces the publish |
| How to Work: shell and repo mechanics | ~3.5k | A `**/*`-scoped rule (see the open questions) |
| How to Work: the rest | ~1.4k | Stays |

The shell and repo mechanics are the bullets on `uv run`, `sudo`, `sleep`,
loops and `$(...)`, timeouts, background teardown, server ports, `gh repo
clone`, reading other clones, and `ast-grep`.

## What does a session load afterwards?

These are estimates from character counts, before trimming the scoped tiers.
The skill listing loads in every session in both columns, and isn't counted.

| Session | Today | Afterwards |
|---|---|---|
| Chat or docs review | 120k | ~38k always-on |
| Design review | 120k | ~38k, plus ~12k skill and the rules it reads |
| Coding | 120k | ~38k, plus ~45k on the first file operation |

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
  depends on what it touched, so a behavior seen in one session can be absent
  from another for that reason alone.
- More files and more indirection: a rule read by both a glob and a skill has
  two ways in, and renaming it means updating the skill too.

## What did I consider and reject?

- **Merging the Hickey cluster** (simple-vs-easy, values-over-places,
  functional-core, declarative, locality-of-behavior) into one file. They
  overlap little, so it saves about 1.5k of headings and references, and it
  breaks the "see the X rule" cross-references across the corpus.
- **Naming skills in `CLAUDE.md`.** The skill listing already loads every
  description in every session; a pointer in `CLAUDE.md` is a second copy of
  it that drifts.
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
  touch the scope; trimming saves in all of them, so the always-on tier gets
  both.

## How does this land?

One commit per move or per rule trimmed, so each diff can be reviewed alone.
Moves change no wording; trims change no destination.

### Phase 1: verify the loading mechanics

- [ ] Confirm a global rule with `paths: ["**/*"]` loads on the first Read in a
  project, using the session transcript (its `nested_memory` attachments) as the
  record, with hooks disabled.
- [ ] Find whether it loads on a Read outside the project root (the scratchpad,
  another clone).
- [ ] Confirm an MCP-only session loads none.
- [ ] Count, from recent transcripts, how many coding sessions here read a file
  with the Read tool before writing code, which is how many would get the code
  tier at all.

### Phase 2: rewrite the doctrine this replaces

- [ ] Rewrite `harness-context.md` around the ranking above: always-on for
  doctrine needed when the situation isn't framed, a file scope for doctrine
  tied to writing a kind of file, a skill for doctrine tied to a named task,
  and the cost of each counted in tokens times the sessions that load it.
- [ ] Update the repo `CLAUDE.md`'s "Claude Code Rules" section to match.

### Phase 3: move without rewording

- [ ] Scope the code tier to `**/*`.
- [ ] Move the ecosystem settings out of `supply-chain.md`.
- [ ] Scope `harness-context.md`, `secrets.md`, and `rfc2119.md`.
- [ ] Create `design-review` and `operations` from the rule text.
- [ ] Move the plan-page bullet into `write-plan`.
- [ ] Move the shell and repo mechanics out of the global `CLAUDE.md`, if
  Josh keeps that move.

### Phase 4: trim the always-on tier

- [ ] Trim each always-on rule, one commit per rule, each for Josh to review.
- [ ] Trim the global `CLAUDE.md`'s remaining sections.
- [ ] Deduplicate `durable-docs.md`'s "Volatile Metrics" against the global
  `CLAUDE.md` bullet, and `verify-empirically.md`'s "run the control" against
  `testing.md`'s "suspect the check on a pass".

### Phase 5: measure

- [ ] Count the always-on total again, and record from transcripts what a chat
  session, a design review, and a coding session each loaded.

## Open questions for Josh

- Do the shell and repo mechanics in "How to Work" move to a `**/*`-scoped rule?
  A few (`sudo`, loops and `$(...)`, `sleep`) govern Bash calls, which a session
  can make before it reads any file, and those would arrive late.
- Does `supply-chain.md` go in the code tier? The harness-context rule's own
  example is that dependency hygiene applies at `cargo add`, a command that can
  come before any file is read.
- Is `making-changes.md` always-on, or code tier? Its refactoring half is code;
  its wrong-abstraction half applies to designs too.
- Does `api-design.md` belong in the code tier with the skill reading it, or
  in the skill alone? An endpoint designed while coding needs it unframed.
- Does this land on #113's branch, or on a new one once #113 merges?
