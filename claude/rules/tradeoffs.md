# Tradeoffs

## Pick an End, in Context, and Name What It Costs

Some choices are a genuine axis with two ends: monorepo vs. polyrepo, library
vs. framework, normalized vs. denormalized, static vs. dynamic dispatch. Each
end buys something by giving something up, and that exchange is the whole
content of the choice.

There's no context-free answer, so don't argue "X is better than Y". Establish
the contextual inputs first, such as:

- **The environment actually in force**: team size, deploy cadence, who
  operates it, what tooling exists, how long it has to live. Treat a choice
  that worked elsewhere as evidence, not an answer.
- **The goals, ranked against each other.** Rank them, don't list them. Each
  end satisfies some of an unranked list, so only a ranking lets one end win.
  Ask for the ranking when it's left implicit.

Then pick an end and say what the design is now bad at. If you can't name what
the choice costs, you haven't made it. Record the ranking with the decision so
a later revisit can tell whether the environment moved or the priorities did,
instead of re-litigating from nothing.

## Don't Chase "Best of Both Worlds"

Don't assume you can take the pros of both ends and the cons of neither. Often
the pros of one end are the cons of the other, restated: a monorepo's atomic
cross-cutting change and its lockstep release cadence are one property seen
from two sides, so you can't keep the first and drop the second. Check each pro
you want against that coupling. The ones that survive it may be independently
obtainable; the rest are what you're giving up. Where they're genuinely
opposed, splitting the difference buys a muddled version of each pro, both sets
of cons, and two mechanisms whose interaction you maintain forever.

Stop and re-pick an end when you notice:

- Some of both happening, with no interface where one end stops and the other
  begins; behavior falls out of accumulated special cases.
- A pitch that lists pros with no matching list of what was surrendered.
- Each new caller needing another flag to fit: the wrong-abstraction signal in
  [[making-changes]], arriving early.
- No way to explain it without explaining both originals first; it's complected
  with both rather than replacing either (see [[simple-vs-easy]]).

## Reach for a Third Approach, Not a Midpoint

Silver bullets exist, but they change the axis instead of sitting on it:

- **`async`/`await`**, over thread-per-request (sequential, readable code, but
  a stack per request) and callback chains (cheap concurrency, but control flow
  turned inside out). The compiler rewrites sequential-looking source into
  resumable state, so the code reads like threads and schedules like callbacks.

- **Persistent data structures**, over copying (safe to share, but cost
  proportional to size on every update) and mutating in place (cheap updates,
  but unsafe to share). An update returns a new version that shares the
  untouched subtrees with the old one, so both stay valid values and the
  copying is proportional to what changed.

Making the choice swappable is one of these too, when you can pull it off. Find
the narrow interface both ends fit behind: the axis then stops being a property
of the system and becomes a parameter of it, and the decision moves to whoever
holds the context. Treat that as an architectural claim, not a configuration
one. The work is finding the cut point, which is found rather than planned (see
[[making-changes]]), and the price is keeping every option working forever
while the interface holds as both sides evolve. Pay that knowingly and it's a
real solution. A config surface with no structure behind it, where the options
reach into each other, doesn't count.

Test a proposed escape by trying to place it on the line between the two
originals. If it lands there, it's a point on that axis subject to the same
exchange, so justify it as one. A real third approach isn't on the line, and
the case for it names the mechanism that makes the original tradeoff not apply.

## References

- [Design Is Compromise](https://stephango.com/design-is-compromise) by Steph Ango
