# Locality of Behaviour (Carson Gross)

Locality of Behaviour (LoB):

> The behaviour of a unit of code should be as obvious as possible by looking
> only at that unit of code.

Put the code on the thing that does the thing. The failure mode is behaviour
you can't discover from the thing it affects: knowing what a button does means
opening the template, the stylesheet, a handler registered by selector, and the
config that wires them together.

## Surface Behaviour, Don't Inline Implementation

Inline the *invocation* of behaviour, not its *implementation*. This is what
keeps LoB from collapsing into "inline everything".

A well-named function call satisfies LoB: the call site says what happens, the
body stays abstracted away elsewhere. What violates LoB is an invocation that's
invisible from the thing it acts on: behaviour registered against a selector, a
decorator scanned at import, a naming convention resolved at runtime.

LoB argues against implicit wiring, not against abstraction. Extracting a helper
is fine; extracting one that attaches itself to its target through a registry
the target never mentions is not.

## Severity Scales With Distance

A violation a few lines away is minor, a page away worse, a separate file worst.
Use LoB as a tiebreaker: prefer the structure that shortens the distance between
a thing and its behaviour.

## Trade It Off Deliberately

LoB conflicts with two widely held principles and doesn't automatically beat
either:

- **Don't Repeat Yourself (DRY)**: one authoritative representation per piece of
  knowledge. Hoisting an attribute repeated across children up onto their parent
  serves DRY and trades away LoB.
- **Separation of Concerns (SoC)**: divide the program into sections that each
  address a distinct concern, canonically markup, style, and logic in separate
  files. Splitting them serves SoC and trades away LoB, since the stylesheet
  then changes an element from a place the element never mentions.

Either trade can be right; make it knowingly rather than reaching for separation
reflexively. SoC files code by *kind*, which serves a reader who wants to see
every style at once, not the more common reader who wants to know what one thing
does.

## References

- [Locality of Behaviour (LoB)](https://htmx.org/essays/locality-of-behaviour/) by Carson Gross
- [The Grug Brained Developer](https://grugbrain.dev/) by Carson Gross
