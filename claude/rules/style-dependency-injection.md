# Dependency Injection

Pass dependencies explicitly as arguments to functions and to class
constructors. Don't reach for globals, singletons, service locators, or DI
frameworks.

Be especially wary of *magical* singletons that hide their nature behind
ordinary syntax, like overriding `__new__` in Python so `MyClass()` silently
returns a shared instance. The call site looks like plain construction, but
it's secretly a global lookup: exactly the hidden coupling DI exists to
surface.

Benefits of this approach:

- Dependencies are visible at the call site: no hidden coupling
- No mocking needed in tests; just pass a different argument
- Lifetime and singleton concerns bubble up naturally to the caller,
  where they can be handled once in a centralized place (e.g., application
  startup)
- No framework magic to learn, debug, or work around

The pattern scales well: at the outermost layer (CLI entrypoint, server
lifespan, test fixture), construct shared objects once and pass them down.
Inner code stays pure and unaware of how those objects were created.
