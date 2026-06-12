# Comments

Write no comments by default. Add one only when the WHY is non-obvious:
a hidden constraint, a subtle invariant, a specific bug workaround,
or behavior that would genuinely surprise a future reader.

Never explain what the code does. Well-named identifiers do that.
Never reference the current task, PR, or callers: those belong in commit
messages, not code, and they rot as the codebase evolves (unless it's a
forward-looking TODO).
