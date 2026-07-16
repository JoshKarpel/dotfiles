# Making Changes

## Make the Change Easy, Then Make the Easy Change

Kent Beck:

> For each desired change, make the change easy (warning: this may be hard),
> then make the easy change.

When asked to make a change, assume similar changes will follow. Before diving
in, ask whether the code is in the right shape to receive not just this change
but the next few like it. If not, restructure so that this and future changes
become easy.

Avoid one-off solutions. Prefer building systems out of composable building
blocks, so each new requirement snaps into place rather than requiring bespoke
logic.

## Don't Factor Ahead of the Evidence

Beck's rule applies to a change you can see coming, not to one you're
imagining. Restructure on evidence: the change you're making now, or one
already asked for.

Wait for *cut points* to emerge: a narrow interface the rest of the system
talks through, with the complexity sealed behind it. Cut points are found, not
planned. Refactor toward them as they appear.

Bias toward waiting. A wrong abstraction costs more than the duplication it
replaced, because every later change has to fight it, and backing it out is
harder than never having added it.

When a decision is forced before the evidence arrives, defer it with a knob:
expose the value you're unsure of as one setting with a sensible default and
settle it later. This works while it stays a value. One setting has a single
live value you can change; a plugin point, a strategy interface, or a second
code path means every branch has to keep working forever, which is the
commitment you were trying to defer.

## Duplication Is Cheaper Than the Wrong Abstraction

Sandi Metz: *duplication is far cheaper than the wrong abstraction*.

DRY is a maxim, not a law. When repeated code is simple and obvious, leave it
repeated. Copy-paste with small variations beats an elaborate object model, a
chain of callbacks, or a parameterized helper carrying five flags.

The signal that an abstraction is already wrong: to make it fit a new caller,
you're passing it another parameter and adding another conditional path. It may
have been right once; that day has passed. Back it out into its callers and
re-extract from what's left, rather than bending it further. Expect the sunk
cost fallacy to argue otherwise, and to argue loudest when the code is worst.

Accumulating a couple of conditionals to gain insight is fine. Bending the
abstraction for the third and fourth caller is not.

## Keep Refactors Small

The larger the refactor, the likelier it fails. Keep the system working at
every step, and finish each step before starting the next: a refactor that
stays broken across many steps can't tell you which step broke it.

Don't introduce new abstraction during a refactor. That's how a cleanup becomes
a rewrite.

## Chesterton's Fence

Don't remove code because it looks ugly or pointless. Work out why it's there
first, and scale that patience to the size of the system.

Tests are often the hint: a case that looks pointless is frequently a bug
someone already paid for. So are `git log` and `git blame` on the lines in
question, which usually name the fence in a commit message.

## References

- [The Wrong Abstraction](https://sandimetz.com/blog/2016/1/20/the-wrong-abstraction) by Sandi Metz
- [The Grug Brained Developer](https://grugbrain.dev/) by Carson Gross
- "Making the change easy, then making the easy change" by Kent Beck
