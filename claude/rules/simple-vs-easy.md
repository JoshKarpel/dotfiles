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

Reference: [Simple Made Easy](https://github.com/matthiasn/talk-transcripts/blob/master/Hickey_Rich/SimpleMadeEasy.md) by Rich Hickey
