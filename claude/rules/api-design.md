# API Design

The shape of an interface between components: requests, responses, schemas, and
the records consumers write back.

## Make the Contract Explicit

- **Transparent behavior becomes the contract.** Whatever an interface does
  silently (decompressing, retrying, normalizing), someone comes to depend on,
  and changing it breaks them (Hyrum's Law). Don't add hidden transforms; when
  two sides must agree on an encoding, often neither should touch the bytes.
- **One field per fact.** Packed strings need parsing everywhere; separate
  fields stay flexible. The exception is a value something routes on: generic
  routers (an ingress, a service mesh) see the path and headers, never the
  body, so a field that picks the backend goes there, even if it implies a
  hierarchy the data lacks.
- **Callers name exactly what they want.** No "latest" alias or fuzzy matching:
  two calls that must hit the same thing need the same identifier, or a race
  slips between them.
- **Don't promise what only one backend provides.** A feature that comes free
  with today's implementation (template inheritance, a storage engine's
  ordering) becomes a promise you must keep after swapping it out. Start from
  deny-all and grant what you mean to support.
- **Remove features that invite misuse.** Before supporting a variant, ask
  whether anyone uses it. An API that's harder to misuse is worth a little
  convenience.
- **Reuse established vocabulary.** Where major vendors or standards already
  name a parameter or endpoint, use their name.
- **Mark pre-GA versions** (`v1beta`), so callers know the contract can still
  change.

## Shape the Data to the Domain

- **Add a sibling type instead of specializing a general one.** When one use
  needs fields a generic type lacks, add a new type that produces the generic
  one rather than growing the generic one into a special case.
- **A required field must apply to every entity.** Attributes only some
  entities have go in a general metadata mechanism, not a column apiece. If
  you aren't ready to commit to a universal concept, name the field narrowly
  for the use you have.
- **Encode the known shape.** An open mapping is less work to write, but it
  pushes every mistake about its contents to runtime. Keep open mappings for
  genuinely open positions.
- **Record events, not just current state.** Status written back ("loaded at
  17:00", "failed to parse at 18:00") is more useful as event history than as
  a mutable field that hides it.
- **Don't pass through what can be derived, unless it can change.** If
  downstream can look a value up from an identifier you already send, and the
  lookup always gives the same answer, don't send it too. If it can change
  before the lookup (a price, a role, a config version), send the value the
  decision used.

## Make Operations Easy to Call Correctly

- **Prefer idempotent "ensure this state" operations.** A create that fails
  when the record exists makes every client branch and switch verbs.
- **Fail invalid requests early, as client errors.** Validate before expensive
  work or enqueueing, and return a 4xx, not a 500 from an uncaught exception.
- **Provide a simple path for small cases,** such as a non-multipart upload
  for small files, so testing and casual use stay cheap.
- **Fix the framework rather than bend the API.** When a framework limitation
  forces an awkward shape, ask whether the framework should gain the feature.

## Evolve Without Breaking

- **Design for versions.** Backward-compatible additions and new versions
  matter more than a perfect first version. Adding a required field is the
  expensive direction, so make fields required while there are no users.
- **Keep identity keys minimal.** Key a record on its smallest unique
  identifier, so it survives later changes (a second actor, a new dimension)
  without rework.

## References

- [Hyrum's Law](https://www.hyrumslaw.com/)
