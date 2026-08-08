---
paths:
  - "**/{AGENTS,CLAUDE,GEMINI,QWEN}.md"
  - "**/rulesync.md"
  - "**/.{claude,codex,cursor,rulesync,windsurf,junie,clinerules,roo,kiro,augment}/**"
  - "**/.{cursorrules,windsurfrules,clinerules}"
  - ".github/copilot-instructions.md"
  - ".github/{instructions,prompts}/**"
  - "**/{rules,commands,skills}/*.md"
  - "**/SKILL.md"
  - "claude/**"
---

# Harness Context Loading

Which mechanism carries a piece of guidance, and when each one loads. This covers
the choice between a hook, a rule, a command, a skill, and an always-on
instructions file; it says nothing about what the guidance should contain.

The organizing question, _who decides that guidance applies_, generalizes across
harnesses; the names below are Claude Code's. A harness offering only one always-on
instructions file collapses the choice to "unconditional or absent", leaving only
the criterion below.

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

`CLAUDE.md` and a path-less rule cost the same, so that choice is editorial:

- `CLAUDE.md` holds personal and harness operating instructions: how to work with
  this user and this tool (don't commit unprompted, don't grind on a blocker,
  prefer `ast-grep`). Coupled to the person and the harness, not portable, never
  cited by name.
- A rule holds portable doctrine: a named, linkable (`[[slug]]`) unit that other
  rules cite ("see the verify-empirically rule") and that carries its own rationale
  and references. That machinery needs a discrete file, not a bullet in a monolith.

The test: could another rule cite it as a principle? Then it's a rule. Is it "how to
work with me" or a harness quirk? Then it's `CLAUDE.md`. Where both apply, keep the
personal framing in `CLAUDE.md` and the citable doctrine in the rule: "don't cite
volatile metrics in replies" against "don't bake volatile metrics into durable
docs".

## Scoped Rules Load Lazily

- A session with no file operations loads no scoped rules at all, `paths: ["*"]`
  included. `*` means "on the first matching file operation", not "always".
- Brace expansion works: `**/*.{py,rs}` normalizes to a list of globs.
- Negation works: `**/*` with `!**/*.md` stays out on markdown files.
- A project-level `.claude/rules/` loads alongside the user-level set.

So guidance informing a decision made before code exists cannot be scoped by path.
Design doctrine applies to a discussion that touches nothing; dependency hygiene
applies at `cargo add`, not when a lockfile is later read. The matching file is
touched after the decision, or never.

Prefer a broad glob with exclusions over an enumerated extension list. An include
list fails by silently not firing when a new language arrives; an exclude list
fails by firing where it doesn't belong, which is visible and cheap to fix.
