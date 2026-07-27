# Comments

Code comments only: prose addressed to the next person reading the
implementation. A docstring is not a comment: it documents an interface for the
people who use it, which makes it a durable doc, so the durable-docs rule
governs it instead of this one.

Write no comments by default. Add one only when the WHY is non-obvious:
a hidden constraint, a subtle invariant, a specific bug workaround,
or behavior that would genuinely surprise a future reader.

Never explain what the code does. Well-named identifiers do that.
Never reference the current task, PR, or callers: those belong in commit
messages, not code, and they rot as the codebase evolves (unless it's a
forward-looking TODO).
