# Declarative over Imperative

Prefer describing *what* you want over prescribing *how* to get it.
Imperative code is a sequence of steps tied to a particular starting state;
declarative code describes a desired end state and leaves the "how" to
something else (a compiler, a query planner, a reconciliation loop).

- **Self-healing systems.** Imperative steps assume a known starting state, so
  interrupted or re-run from an unexpected one, they can leave things half-done.
  A description of the end state lets a reconciler repeatedly diff actual
  against desired and converge from *any* starting point, which is why
  Kubernetes, Terraform, and SQL work this way.
- **Abstractions.** Naming the *what* cleanly, apart from the *how*, is the
  essence of a good abstraction.
  If you can't describe what you want without also specifying the mechanism,
  the boundary is probably in the wrong place: policy and mechanism are
  braided together where they could be independent.
- **Optimization.** When the caller only states intent, the implementation
  stays free to choose, and later change, its strategy without breaking the
  contract.
  Decoupling "what do you want" from "how and when it happens" (the leverage
  behind command-query separation) leaves the engine room to reorder, batch,
  cache, or parallelize: a SQL query says "give me X", and the planner picks
  the index, the join order, and the plan, none of which the caller could
  safely hardcode.
- **One declaration, recovered not restated.** Whichever layer parses or
  produces a value owns the description of its shape.
  Secondary representations (an API schema, a diagram, a dependency graph) are
  *recovered* from that declaration, never maintained alongside it: a parallel
  description is a second copy that drifts, so derive it from the structure.
  One source needn't mean one representation: a pattern encoded once
  (templated config values, say) can generate names, URLs, and counts across
  several artifacts, none of them a copy.
- **An imperative upstream wants a workflow, not a reconciler.** When upstream
  sends commands (create this, copy that, delete it) rather than a desired
  state, run each as a durable workflow: it retries and resumes from any
  interruption, with less impedance mismatch than translating commands into
  desired state for a reconciler.
