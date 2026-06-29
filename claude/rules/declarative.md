# Declarative over Imperative

Prefer describing *what* you want over prescribing *how* to get it, step by
step. Imperative code is a sequence of instructions tied to a particular
starting state; declarative code is a description of a desired end state,
leaving the "how" to something else (a compiler, a query planner, a
reconciliation loop).

- **Self-healing systems.** Imperative steps assume the world is in a known
  state before they run; interrupted or re-run from an unexpected state, they
  can leave things half-done. A declarative description of the desired end
  state lets a reconciler repeatedly diff actual vs. desired and converge,
  recovering from *any* starting point. This is why Kubernetes, Terraform, and
  SQL all work this way: you state the goal and the system retries its way
  there.
- **Abstractions.** Naming the *what* cleanly, separate from the *how*, is the
  essence of a good abstraction. If you can't describe what you want without
  also specifying the mechanism, the boundary is probably in the wrong place:
  policy and mechanism are complected (see Simple vs. Easy).
- **Optimization.** When the caller only states intent, the implementation
  stays free to choose (and later change) its strategy without breaking the
  contract. This is the same leverage behind command-query separation:
  decoupling "what do you want" from "how and when it happens" gives the
  engine room to reorder, batch, cache, or parallelize. A SQL query says
  "give me X"; the planner picks the index, the join order, the execution
  plan, none of which the caller needs to know or could safely hardcode.
- **One declaration, recovered not restated.** Whichever layer parses or
  produces a value owns the description of that value's shape; secondary
  representations (an API schema, a diagram, a dependency graph) are *recovered*
  from that single declaration, never maintained alongside it. A description
  kept in parallel with the code it describes is denormalized state that drifts;
  derive it from the structure so it can't. This is the declarative move applied
  to a system describing itself: state the shape once, compute the rest.
