# Platforms and Their Consumers

Who owns a shared component (a platform, a shared service, a library many teams
build on), and how the line between it and its consumers is drawn and held.

## Assign Ownership by Who Can Verify the Change

These are anchors, not a rubric: no one question settles ownership, and the
answers move with the system, so re-ask them periodically.

- **Own what you can check.** A change whose correctness a type checker or
  unit, integration, performance, or conformance tests can decide leans
  platform. One that needs an eval, a domain expert, or customer feedback leans
  consumer, since only the consumer can tell whether it's right.
- **Ask who gets paged first.** When no single team is the obvious answer, the
  component is probably two; split it along an interface and ask again of each
  half.
- **Undecided defaults to the consumer.** A component that proves its worth can
  be promoted into the platform later; the reverse is far more disruptive, and
  what lands in a platform rarely leaves.
- **Shared is not the same as platform-owned.** Code many consumers use can be
  a library owned by whichever team has opinions about it. Being common is not
  by itself a reason for the platform team to own it.
- **A flag per consumer is a component per consumer.** A shared component with
  twenty boolean flags is twenty consumer-owned components in a trench coat;
  see the making-changes rule on the wrong abstraction.

## Platforms Configure; Consumers Decide

- **Build what consumers configure, not what does their work.** What to do with
  the data is the consumer's business logic; how and when it arrives (batching,
  retries, scaling, delivery) is the platform's. Keep that split even when
  absorbing the consumer's logic looks like a favor.
- **Don't own logic every consumer must specialize.** Where each use needs its
  own variant, or requirements keep drifting, give the consumer a composition
  mechanism it owns. A fixed code path in the platform turns every change into
  cross-team coordination.
- **Don't make product decisions on consumers' behalf.** A behavior with
  product implications (localization, fallback models, retention) is opt-in,
  adopted by the team that owns the feature, not on for everyone by default.
- **Put responsibility with the party that has the context.** Don't add a check
  the platform can't actually make. An isolation boundary, for instance, is an
  opaque key the caller supplies, not a relationship the platform must prove.
- **Generic is the point.** A platform that keeps adapting to individual
  consumers' business logic builds solutions, not leverage.

## Hide Mechanism, Expose Decisions

- **Publish named behaviors; keep the parameters private.** A profile named for
  what it does ("bursty, scale to zero") is the stable contract; the numbers
  behind it are the owner's to retune.
- **Don't expose a knob consumers can't reason about.** A setting whose cost
  multiplies out of sight (a per-model resource request times every tenant
  that loads it) belongs to whoever can see the product.
- **Hide internals, not facts consumers decide on.** Sharding, storage layout,
  and message formats stay private, even from trusted internal callers; where
  the data is processed, and anything else a consumer's compliance depends on,
  stays visible.
- **Internal names match the external ones.** The name in the user-facing docs
  is the name in the code.

## Enforce Structurally

Defaults in the centrally owned template, generated ownership files, CI checks,
and framework-level protections beat asking people to behave. Controls form a
ladder (inform, advise, detect after the fact, block, offer only a wrapper):
take the lowest rung that gives enough confidence, and count docs as the first
rung, a real control but the weakest.

## Breakage Costs Land Somewhere

- **Pinning defers and multiplies migration cost.** Consumers on old versions
  still pay to migrate, separately and later, and nobody learns whom a change
  broke until each one upgrades. Versioning lets consumers choose when to
  break; it doesn't make them break less.
- **Producers pay for breaking consumers.** Validate changes against consumers
  before shipping: run their tests where they share the repository, or, for a
  published library, validate through its own tests and examples and fix
  forward. A producer that bears part of the cost of a break has a reason to
  avoid one.
- **Relocating the pain doesn't remove it.** Moving churning code elsewhere
  doesn't make it break less, and shifting the burden onto consumers raises
  the total. Ask whether a proposed process fix is covering a testing gap.
- **Share a structure for the workflows it enables.** Sharing a repository,
  database, or deployment pays off in what only sharing allows: atomic
  cross-cutting change, consumers living at head, joins across teams' data.
  Sharing the structure while rebuilding isolation inside it (independently
  versioned packages in a monorepo, per-team schemas nobody joins across) pays
  the costs of both. Ask how much of such a proposal would vanish if the parts
  were simply separate.

## Operational Burden Is the Cost to Minimize

- **Maintenance and operations aren't virtues; drive them toward zero.** A
  system whose business logic didn't change should need no human action, so
  deploy on a schedule or continuously, not by hand.
- **The responder is whoever has to fix it.** Owners alert on their own
  failure modes; a downstream team shouldn't be the notification mechanism. A
  platform provides the alerts and runbooks, not the attention.
- **Operate once, where the expertise is.** Don't make every consumer run its
  own rotation for shared infrastructure. Count each replica's fixed overhead
  concretely (the rotation, its alerts, meetings, and on-call pay) when arguing
  against duplicating it.
- **Build for operators who weren't there.** Assume the original authors won't
  be around to support it.
- **The owning team's load must grow sublinearly.** If each new consumer adds
  roughly constant work for the platform team, the platform caps everyone's
  velocity at that team's.
