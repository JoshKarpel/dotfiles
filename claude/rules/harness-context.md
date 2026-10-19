# Harness Context Loading

Which mechanism carries a piece of guidance, and when each one loads. This covers
the choice between a hook, a rule, a command, a skill, and an always-on
instructions file; it says nothing about what the guidance should contain.

The organizing question, _who decides that guidance applies_, generalizes across
harnesses; the names below are Claude Code's. A harness offering only one always-on
instructions file collapses the choice to "unconditional or absent", leaving only
the criterion below.

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
| Rule with `paths:` | The harness, on a file glob | On a matching file operation | Silent: no file operation, no rule |
| Command | The user, explicitly | When typed | None; the user sees it didn't run |
| Skill | The model, from the description | When the model judges it relevant | Silent, and self-referential |

A hook is the only one that _enforces_ rather than advises. It runs outside the
model, so it can block an action or gate a stop whatever the model concluded.

## Nothing Conditional May Carry Answer-Changing Doctrine

Guidance that would change the conclusion loads unconditionally. Conditional
mechanisms carry only additive material: file-format specifics, or a procedure for
a situation someone will name out loud.

The always-on set is the contract, the part of the environment that is identical in
every session. Its context cost is what buys that consistency, so trimming it
spends confidence that today's environment matches yesterday's.

## A Skill Cannot Correct the Judgment That Loads It

Skill activation is decided by the same model whose default the doctrine exists to
override. "Avoid fallback" is needed precisely when the model has _not_ framed the
situation as a fallback decision, which is precisely when it won't load the skill.
The gap is structural, not a description to tune.

Skills work when the user states the trigger: a failed CI run, a slow query, a
review to work through. Nothing has to be recognized in advance.

## Choosing a Mechanism

First match wins.

- **Must it happen whatever the model concludes?** A hook.
- **Would its absence change the answer?** Unconditional text, `CLAUDE.md` or a
  path-less rule. Never a skill.
- **Should the user trigger it deliberately?** A command. It costs nothing until
  typed.
- **Is it a procedure for a situation the user will name?** A skill. Size it
  freely, since it only loads when invoked.
- **Does it only make sense while looking at a file of a given kind?** A rule with
  `paths:`.

`CLAUDE.md` and a path-less rule cost the same, so that choice is editorial: how to
work with this user and this harness goes in `CLAUDE.md`, and portable doctrine
that another rule could cite as a principle goes in a rule.

## Scoped Rules Load Lazily

A session with no file operations loads no scoped rules at all, `paths: ["*"]`
included: `*` means "on the first matching file operation", not "always". So
guidance informing a decision made before code exists cannot be scoped by path.
Design doctrine applies to a discussion that touches nothing; dependency hygiene
applies at `cargo add`, not when a lockfile is later read. The matching file is
touched after the decision, or never.
