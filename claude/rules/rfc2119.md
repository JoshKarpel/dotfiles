# RFC 2119 Normative Keywords

## When to Use

RFC 2119 keywords are for specifications that impose requirements on
implementations or behaviors: specs, API contracts, protocol docs, READMEs
that define required behavior, and docstrings for public APIs or interfaces.
Don't use them in tutorials, changelogs, or casual prose where they read as
emphasis rather than requirements.

## Capitalization

Capitalize the full keyword when using it in the RFC 2119 sense. Lowercase
`must`, `should`, `may` is plain English and does not carry normative weight.

## Keyword Definitions

| Keyword | Meaning |
|---|---|
| MUST / REQUIRED / SHALL | Absolute requirement |
| MUST NOT / SHALL NOT | Absolute prohibition |
| SHOULD / RECOMMENDED | Strong recommendation; deviation requires understanding and weighing the full implications |
| SHOULD NOT / NOT RECOMMENDED | Strong discouragement; permitted only with understood tradeoffs |
| MAY / OPTIONAL | Truly optional; implementations that include or omit it MUST still interoperate |

## Use Sparingly

Use normative keywords only where required for interoperation or to limit
harmful behavior. Don't use them to impose implementation choices when
interoperability doesn't require it. Overuse dilutes their meaning.

## Boilerplate

In formal spec documents, include this line near the top to make the
interpretation explicit:

> The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT",
> "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this
> document are to be interpreted as described in
> [RFC 2119](https://datatracker.ietf.org/doc/html/rfc2119).
