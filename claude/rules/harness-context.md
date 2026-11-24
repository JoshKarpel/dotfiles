---
paths:
  - "**/CLAUDE.md"
  - "**/AGENTS.md"
  - "**/GEMINI.md"
  - "**/.claude/**"
  - "claude/**"
  - "**/.agents/**"
  - "**/.codex/**"
  - "**/.cursor/**"
  - "**/.github/copilot-instructions.md"
  - "**/.github/instructions/**"
  - "**/.clinerules/**"
  - "**/.devin/**"
  - "**/.windsurf/**"
  - "**/.kiro/**"
  - "**/.opencode/**"
  - "**/.roo/**"
  - "**/.junie/**"
  - "**/.rulesync/**"
---

# Harness Context Loading

Which mechanism carries a piece of guidance, and when each one loads: a hook,
an always-on file (`CLAUDE.md` or a path-less rule), a rule with `paths:`, a
command, or a skill. It says nothing about what the guidance should contain.
The names are Claude Code's; the organizing question, _who decides that
guidance applies_, carries to any harness.

## A Session Is Not Storage

Nothing learned in a session survives it. When a correction, a hard-won
constraint, or a settled convention is worth keeping, write it into one of the
mechanisms below, committed to the repository that owns the harness config.
Guidance living anywhere else is unversioned, unreviewable, and absent from the
next machine.

The trigger is sometimes stated outright. When it isn't, supply it: being
corrected twice on the same thing, or establishing a constraint that cost an
hour, is the signal to say where the lesson belongs before moving on.

## Who Decides It Applies

| Mechanism | Who decides | Loads | Failure mode |
|---|---|---|---|
| Hook | The harness, on an event and matcher | When the event fires | Loud: a broken hook errors |
| `CLAUDE.md`, path-less rule | Nobody; unconditional | Every session | Context cost, always paid |
| Rule with `paths:` | The harness, on a file glob | On the first Read of a matching file inside the project | Silent: no such Read, no rule |
| Command | The user, explicitly | When typed | None; the user sees it didn't run |
| Skill | The model, from the description | When the model judges it relevant | Silent, and self-referential |

A hook is the only one that _enforces_ rather than advises. It runs outside the
model, so it can block an action or gate a stop whatever the model concluded:
anything that must happen regardless is a hook. A command costs nothing until
typed, so it suits what the user wants to trigger deliberately.

A hook can also supply context. What every session needs but is only true at a
point in time (repo state, available recipes, the current toolchain version)
wants a `SessionStart` hook that computes it at startup, not a hand-maintained
list that drifts.

## Worldview, Mechanics, and Procedure

The always-on set teaches how I think, and I bring all of it to every problem,
so it's judged holistically. It is also the contract: the part of the environment that is identical in every session.
What sorts a passage is what kind of guidance it is:

- **Worldview** is a principle or a way of judging. It holds across languages,
  tools, and kinds of work, and it's needed precisely when nobody has framed
  the situation as the one it covers. It goes always-on.
- **Mechanics** are facts about one tool, format, or platform: a flag, a config
  knob, a gotcha. They go in a rule scoped to the files that are open when they
  matter. A mechanic that misses its scope costs a rediscovered flag, which a
  `--help` or a probe recovers.
- **Procedure** is a checklist for a task someone names out loud: an incident
  review, publishing a plan's page. It goes in a skill.

Some mechanics are keyed to an action rather than a file: a shell construct
that triggers a permission prompt, a `sleep` to wait on background work, an
unset variable in a path. Nobody frames that moment as a task, so a skill won't
load for it. Where the command text shows the action, a `PreToolUse` hook
matching it is the scope, and its block message carries the guidance at the
moment it applies; the always-on text keeps only the reason the message can't
give. Where no hook can recognize the action, the mechanic stays always-on.

The test for a passage: would it still be true and useful if the tool it names
didn't exist? Worldview passes, even when it uses a tool as its example. When a
passage's kind is in doubt, it stays always-on: missing doctrine costs a wrong
answer, and carrying it costs tokens.

`CLAUDE.md` and a path-less rule cost the same, so that choice is editorial: how
to work with this user and this harness goes in `CLAUDE.md`, and portable
doctrine goes in a rule.

## A Skill Cannot Correct the Judgment That Loads It

Skill activation is decided by the same model whose default the doctrine exists
to override. "Avoid fallback" is needed precisely when the model has _not_
framed the situation as a fallback decision, which is precisely when it won't
load a skill about fallback. The gap is structural, not a description to tune.
Skills work when the trigger is stated: a failed CI run, a review to work
through, a plan to publish.

## Scoped Rules Load on Reads Inside the Project

- A rule with `paths:` loads its body the first time the Read tool opens a
  matching file inside the project root. Creating a file with Write, a Bash
  `cat` or `sed`, and Grep load nothing; Edit needs a prior Read, so editing an
  existing file does. A Read outside the project root (another clone, a
  scratchpad worktree) loads nothing, even through `--add-dir`.
- So guidance that informs a decision made before any file is read can't be
  scoped. Design doctrine applies to a discussion that touches nothing;
  dependency hygiene applies at `cargo add`, before any lockfile is read.
- Write the glob for the files open when the mechanic matters, not the
  narrowest pattern that names the tool: a narrower glob fires in fewer
  sessions.
- A skill's `paths:` doesn't load the skill. It adds the description to the
  listing on a matching Read, and the body still waits for invocation.
- A skill or an always-on line can name a rule's path for the model to read,
  which reaches a scoped rule from a task that opens no matching file.

## Slice Small, and Write Each Rule to Stand Alone

The always-on files arrive as one block, each under a header of about 130
characters naming its path, and a scoped rule arrives under the same header. A
file boundary is cheap, and a file name is only an address. So:

- **Split by what loads it, not by topic.** One tool's mechanics belong with
  that tool's files, apart from the worldview they illustrate. A slice should
  still outweigh its header.
- **Each rule makes sense read alone.** Gloss a borrowed term in a clause where
  it's used, and state an idea outright rather than as an analogy to another
  rule. A pointer to another rule is somewhere to read more, never something
  the citing rule depends on. A rule that stands alone can later be scoped or
  moved on the evidence about that rule alone.
- **Don't write which rule owns which topic.** That's maintenance guidance for
  whoever edits the corpus, and it goes stale on the next split.

## Editing Always-On Text

Compress words, not ideas. `git log -L` on a passage shows whether a
`harvest-sessions` pass or a fix for an observed mistake added it, or whether it
was written up front. A passage a correction added is the best evidence of what
sessions rely on: it keeps its claim, may be reworded tighter, and goes only
when another rule says the same thing. Cut restatements, second examples making
the same point, and framing with no claim. Don't compress to a percentage
target, which forces the cuts into the corrected passages.
