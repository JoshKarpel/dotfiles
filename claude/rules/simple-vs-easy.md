# Simple vs. Easy (Rich Hickey)

**Simple** means unentangled: one concern, no interleaving with other things.
It's objective: you can inspect a piece of code and determine whether it's
braided together with something else or truly independent.

**Easy** means familiar or close at hand. It's subjective and person-relative.

These are orthogonal. Don't confuse ease of writing with simplicity of the
result. A construct that's fast to reach for can produce a complected system;
a harder upfront choice can produce one that's easy to change for years.

**Complecting** is Hickey's term for braiding together things that could be
independent: state with identity, function with state, timing with logic,
policy with mechanism. It's how complexity accumulates. When something feels
hard to change or reason about, look for what it's been complected with.

Optimize for the simplicity of the artifact (the running system), not the
convenience of the author. Easy-to-write code that's complected is a
slow-burning problem.

But optimizing the artifact means its simplicity, not its *symmetry*. Two sides
of an interface looking uniform is an aesthetic property, not evidence they're
unentangled. When an asymmetry is real (one side holds the continuation and
calls inward, the other is called and reacts), forcing both into one shape
contorts the caller's code to make the library merely *look* symmetric. The same
trap is a framework that inverts your control flow to present a uniform surface:
a library that hands back plain values and leaves the control flow with you is
the less symmetric and the simpler one. Simple means unentangled, not matching.

Reference: [Simple Made Easy](https://github.com/matthiasn/talk-transcripts/blob/master/Hickey_Rich/SimpleMadeEasy.md) by Rich Hickey
