# Control Plane / Data Plane Separation

Management operations (cache expiration, config refresh, lease renewal,
cleanup jobs) belong in a separate control plane, not in the request
processing path. The *control plane* manages system state; the *data plane*
handles individual requests. Entangling them is a form of complecting
(see Simple vs. Easy).

- **Keep management off the hot path.** Expiring a cache entry or refreshing
  a config during request handling couples an administrative concern to
  latency-sensitive code. The request now bears the cost of the management
  work, and the management work is triggered by request volume rather than
  by policy. Move it to a background process or scheduled job.
- **Run each task the right number of times.** In a horizontally scaled
  deployment, code that runs once per process runs N times per logical unit,
  once per replica. Cache expiration that fires on every request in every pod
  isn't resilience; it's redundant work with races. Identify the correct
  cardinality (per-deployment, per-cluster, per-interval) and enforce it
  structurally: a single scheduled job, a distributed lock, or leader election.
- **Distribute results, not work.** When the control plane produces data, push
  the result into a shared store (Redis, a config map, a pub/sub topic) so
  all data plane instances read from it without each redoing the work. The
  work happens once; the result is available everywhere.
