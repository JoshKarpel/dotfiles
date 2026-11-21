# Dependency Injection

Pass dependencies explicitly as arguments to functions and class constructors,
not through globals, singletons, service locators, or DI frameworks.
Be especially wary of *magical* singletons hidden behind ordinary syntax, like
overriding `__new__` in Python so `MyClass()` silently returns a shared
instance: the call site looks like plain construction but is secretly a global
lookup, exactly the hidden coupling DI exists to surface.

The payoffs:

- Dependencies are visible at the call site.
- Tests need no mocking; they pass a different argument.
- Lifetime and singleton concerns bubble up to the caller, to be handled once
  in a central place.
- No framework magic to learn, debug, or work around.

At the outermost layer (CLI entrypoint, server lifespan, test fixture),
construct shared objects once and pass them down; inner code stays pure and
unaware of how they were created.
