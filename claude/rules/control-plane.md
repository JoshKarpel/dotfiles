# Control Plane / Data Plane Separation

Management operations (cache expiration, config refresh, lease renewal,
cleanup jobs) belong in a separate control plane, not in the request path.
The *control plane* manages system state; the *data plane* handles individual
requests.
Entangling them is complecting: braiding independent concerns together.

The separation is worth pursuing at any scale.
Across services, the control plane is a separate process or a scheduled job.
Within a single process, where separating it at the system or architecture
layer isn't feasible or worth the effort, it's a background thread or a
scheduled task.
Either way, request handlers do no management work.

- **Keep management off the hot path.** Expiring a cache entry or refreshing a
  config during request handling makes the latency-sensitive request bear the
  cost of the management work, and makes request volume rather than policy
  trigger it.
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
