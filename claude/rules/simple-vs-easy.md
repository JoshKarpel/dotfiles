# Simple vs. Easy (Rich Hickey)

**Simple** means unentangled: one concern, not braided with anything else.
It's objective, so you can inspect code and tell whether it's tangled
with something else.
**Easy** means familiar or close at hand, which is subjective.
The two are orthogonal:
a construct that's fast to reach for can produce a tangled system,
and a harder upfront choice can produce one that's easy to change for years.

**Complecting** is Hickey's term for braiding together things
that could be independent: state with identity, function with state,
timing with logic, policy with mechanism.
It's how complexity accumulates, so when something is hard to change
or reason about, look for what it's been complected with.

Optimize for the simplicity of the artifact (the running system),
not the convenience of its author.

Simplicity is not *symmetry*.
Two sides of an interface looking uniform is an aesthetic property,
not evidence they're unentangled.
When an asymmetry is real (one side holds the continuation
and calls inward, the other is called and reacts),
forcing both into one shape contorts the caller's code
so the library merely *looks* symmetric.
The same trap is a framework that inverts your control flow
to present a uniform surface: a library that hands back plain values
and leaves the control flow with you is the less symmetric and the simpler one.

Reference:
[Simple Made Easy](https://github.com/matthiasn/talk-transcripts/blob/773d2992d72d5b7e8c5d06264c498b7a3c8f604e/Hickey_Rich/SimpleMadeEasy.md)
by Rich Hickey
