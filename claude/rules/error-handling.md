# Error Handling

## Fail Loud on Broken Contracts

- **Let unexpected input fail.**
  When data doesn't match what the code expects,
  prefer failing over silently skipping or swallowing it.
  Quietly dropping a malformed file or an unrecognized case hides the problem;
  a loud failure surfaces it so we can decide deliberately how to handle it.
- **Valid-but-optional is not malformed.**
  Fail loud on input that violates the contract,
  not on input that satisfies it in a way this consumer doesn't care about.
  A producer adding an optional field (a new event kind, a trailing header)
  must never crash a consumer that didn't ask for it;
  ignoring it is a deliberate choice, not a swallowed error.
  Put strictness only where something is _required_:
  the consumer that demands the value raises in its own terms when it's absent,
  instead of every consumer rejecting anything extra.

## Choose the Failure Direction

Some failure is unavoidable, so make the likely one harmless.

- **Order steps so an interruption leaves the benign state.**
  Don't tell a client its work is queued before it durably is,
  or a crash in between loses work the client thinks is safe.
  Acknowledge a message only after its effect has succeeded
  or exhausted its retries.
- **Don't promise durability the store lacks.**
  If the store can lose data, pick semantics where the loss errs harmlessly:
  a rate limit on a wipeable cache can reset early,
  but can't honestly offer a lifetime cap.
- **Silent and costly is the worst failure.**
  A loud error gets fixed; a silent miscount that bills customers wrongly,
  or a fail-open that ignores a control a customer configured,
  does damage until someone audits it.
  Design those out first, even at the price of more loud failures.
- **State the delivery semantics and who owns each failure.**
  At-least-once delivery makes idempotency the client's job; say so,
  and say which team investigates which class of failure.

## Don't Handle What Can't Occur

- **Don't add error handling, fallbacks, or validation for paths
  that can't occur**, such as cases the types or call sites already rule out.
- **Don't bubble-wrap preemptively.**
  Don't wrap code in `try`/`except` and failure logging
  before experience shows it's needed:
  speculative handling adds noise and buries real bugs.
  This bites harder in exception-based languages, where a bare `except`
  or a defensive `.get()` in Python swallows problems invisibly, than
  in result-based ones like Rust, whose types force the error to the surface.
- **The strongest form is to make the bad state unrepresentable:** design types
  so it can't be constructed in the first place.

## Avoid Fallback

- **Fallback is the one strategy to avoid.**
  Retry (run it again, after a delay),
  proactive retry (run several copies in parallel, take the first to finish),
  and failover (run it against a different copy of the endpoint)
  all re-run the same code path, so production exercises them constantly.
  Fallback reaches for a _different mechanism_, a second path that runs only
  when the first is already failing: its bugs stay latent for months or years,
  testing it means reproducing the correlated failure that triggers it,
  and it can fail too, so it lowers the odds of total failure rather
  than removing them.
- **Ask why the fallback isn't the primary.**
  It trades something away (latency, a consistency guarantee, load
  on another component), or you would use it always.
  Name that trade,
  then ask why it's acceptable at the moment the system is least healthy.
  Usually it isn't, because the cost lands during an incident,
  on top of the original problem.
- **Correlated failure makes fallback amplify.**
  The trigger is rarely one machine:
  a shared dependency dies and every caller falls back at once,
  onto a target provisioned for overflow rather than full load.
  If the target can't carry every caller at once,
  the fallback turns a partial failure (one feature degraded) into a total one,
  and widens the blast radius to that target's other clients.
- **Prefer, in order:** make the primary path more reliable,
  since it runs on every request and the fallback once a year;
  let the caller handle the error,
  which it usually already retries and has the context to interpret;
  make the data resident before the request arrives,
  so there's no remote call left to fail; or, if a second path must exist,
  exercise it continuously and treat its result as equally valid,
  which makes it failover rather than fallback.
- **A cache with a fall-through path is fallback.**
  Falling through to the origin
  when the cache tier fails is the amplifying case:
  the cache exists because the origin can't carry full traffic,
  so the fall-through arrives as a correlated stampede.
  Serving stale entries when a refresh fails is the quieter case,
  a second data path whose staleness bound nobody chose and no test exercises.
  Decide which kind of cache it is.
  If the origin can carry full load, the cache is an optimization and falling
  through is safe; if not, the cache is a hard dependency, so size
  and operate it as one instead of keeping a path that pretends otherwise.
- **Get the data off the request path.**
  A demand-filled cache puts a remote call inside the request,
  then needs a policy for when that call fails.
  Remove the call instead: have a control plane push the data to each consumer,
  or have the consumer load it at startup before it reports ready and refresh it
  in the background on a timer or a watch.
  Either way, no request ever triggers the fetch,
  so each failure has an obvious answer rather than a fallback:
  a failed initial load means the instance never goes ready
  and takes no traffic,
  and a failed refresh means keep serving the last good value, alarm,
  and hold to a staleness bound chosen up front.
  A shared store falls short of this,
  since reading it is still a remote call on the hot path.
  It needs data small enough to hold locally that changes slowly relative
  to request rate.
- **Watch for retries becoming fallback.**
  Retries insure against _transient and uncorrelated_ errors:
  spurious packet loss, one bad machine.
  Firing for correlated reasons, they're dormant code multiplying load onto
  a dependency that is already overloaded.
  Alarm on retry rate, not just error rate; it rises before the errors do.
  Proactive retry avoids this by construction: the redundant requests are always
  in flight, so a surge in failures adds no load (the constant-work pattern,
  which quorum reads and writes get for free).

## References

- [Avoiding fallback in distributed systems](https://builder.aws.com/content/3EuS9Sakq7L3VLQIF3qzfMfke1Y/avoiding-fallback-in-distributed-systems)
  by Jacob Gabrielson
