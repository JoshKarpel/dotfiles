# Comments

Prose in the implementation: comments, and whether a docstring is worth
writing. How that docstring's prose reads once it exists belongs to the
durable-docs rule, since a docstring documents an interface for the people who
use it.

## A Comment Is Guidance at the Tightest Scope

A comment is a **guidance file** scoped to one region of one file. `CLAUDE.md`
loads in every session, a rule with `paths:` loads on a matching file
operation, and a comment loads when whoever is about to change this code reads
it. Same job at a smaller blast radius: tell the next editor what they have to
know before they touch this.

That fixes the audience, which is what sorts a comment worth writing from one
that isn't. A comment addressed to whoever _reads_ the code is narration, and
the code serves that reader better than prose can. A comment addressed to
whoever _changes_ it is guidance. Write guidance:

- The constraint that ruled out the obvious approach, so the next editor
  doesn't re-derive it and "fix" the code back.
- The invariant the next edit will silently break.
- The specific bug a strange line works around, named with its cause.
- Why an ordering matters.
- A forward-looking TODO.

Nothing loads a comment. A rule has a glob and a hook has an event, but a
comment fires only if whoever is editing reads that far, so it goes _on_ the
line it governs. A caveat about a loop's exit condition, parked in a banner at
the top of the file, is guidance that won't be in context at the moment it was
written for.

## Guidance Has a Budget

Every comment is read by everyone who edits that region, the way `CLAUDE.md` is
paid for by every session. A file where everything is commented teaches
nothing: the lines carrying a real constraint are indistinguishable from the
ones restating the code, so all of them get skimmed.

The question for each one is therefore not "is this true" but "would I put this
sentence in `CLAUDE.md` if it held repo-wide". A sentence that fails it isn't
too small to be guidance, it isn't guidance.

Put guidance at the tightest scope where it holds. A convention that holds
across the repository belongs in `CLAUDE.md` or a rule, not restated in forty
files where the copies drift. A constraint that holds for one function belongs
on that function, not in a rule that costs context in every session that never
opens the file.

## Habits That Fail the Test

Every one of these is a comment worth deleting rather than rewording.

- **The phase label.** `# Validate the payload`, above the block that validates
  the payload. The phase wants to be a call to a named function, which says the
  same thing in a form that can be read on its own, tested, and reused.
- **The signature restated.** An `Args:`/`Returns:` block listing parameters
  the types already carry, or a summary line that is the function's name in a
  sentence. Whatever surfaces a docstring surfaces the signature beside it, so
  this is padding for every audience. Document the contract the signature
  can't hold: what an empty input does, what it raises, which argument
  combinations are illegal. The padding is the failure here, not the
  docstring; see below.
- **The change narrated.** `# Now handles the empty case`, `# Switched to the
  async client`, `# Kept for the old signature`, `# As requested`. These
  address whoever is reading the diff today, and they describe a past the file
  stops being able to confirm as soon as it moves again. History goes in the
  commit message; the current task, the PR, and the calling code go nowhere.
- **The assumption flagged.** `# Assumes the API returns ISO-8601 timestamps`
  records that the author was unsure. Confirm it and write the constraint
  instead (`parsing here breaks if the API stops returning ISO-8601`), per the
  verify-empirically rule, or leave it out and raise it in the reply. A guess
  pinned to the code is read as an established fact within a week.
- **The reasoning shown.** A comment demonstrating that the author understood
  the request belongs in the answer to the request.

## Docstrings Load Wherever the Name Appears

A comment reaches only whoever reads that region of that file. A docstring
travels with the symbol, surfacing on a grep hit, an editor hover, an imported
name in another file, a type stub, a partial read. It therefore reaches an
agent that is about to call or edit the thing without ever seeing its body,
which is the common case rather than the exception.

So write one on everything, private one-line helpers included. The budget above
binds comments harder than docstrings: comments dilute each other in a file
read start to finish, while a docstring is retrieved on its own and competes
only with whatever surfaces beside that one name.

What it carries is still the _why_. For a small helper that's why it exists at
all and what invariant it holds, not a sentence that reads out its body.

A module docstring says what role the module plays in the wider system and what
belongs in it. That is guidance for the editor deciding where new code goes,
and nothing else in the file supplies it. Listing the classes defined below is
the failure mode, not the module docstring itself.
