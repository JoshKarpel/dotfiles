# Control Plane / Data Plane Separation

Management operations (cache expiration, config refresh, lease renewal,
cleanup jobs) belong in a separate control plane, not in the request path.
The *control plane* manages system state; the *data plane* handles individual
requests.
Entangling them is complecting: braiding independent concerns together.

The separation is worth pursuing at any scale, not only across services: even
within a single process, keep management work on a background thread or
scheduled task rather than in request handlers, even where separating it at
the system or architecture layer isn't feasible or worth the effort.

- **Keep management off the hot path.** Expiring a cache entry or refreshing a
  config during request handling makes the latency-sensitive request bear the
  cost of the management work, and makes request volume rather than policy
  trigger it.
  Move it to a background process or scheduled job.
- **Run each task the right number of times.** In a horizontally scaled
  deployment, code that runs once per process runs once per replica, N times
  per logical unit.
  Cache expiration that fires on every request in every pod isn't resilience;
  it's redundant work with races.
  Identify the correct cardinality (per-deployment, per-cluster, per-interval)
  and enforce it structurally: a single scheduled job, a distributed lock, or
  leader election.
- **Distribute results, not work.** When the control plane produces data, push
  the result into a shared store (Redis, a config map, a pub/sub topic) that
  every data plane instance reads, so the work happens once and the result is
  available everywhere.
