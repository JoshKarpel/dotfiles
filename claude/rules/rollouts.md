# Rollouts and Migrations

- **Make the safe intermediate state the steady state.**
  If an operation is safe only
  while the system is temporarily configured some way (extra replicas,
  a redundant assignment), consider running that way permanently:
  it removes the toil of entering and leaving it, and usually adds resilience.
- **Run the new path beside the old behind a switch.**
  Read the switch at startup, flip it per environment,
  and roll back by flipping it back.
  Plan to delete the old path once the new one is stable.
- **Migrate one thing at a time.**
  Start in the lowest environment, avoid long-lived branches,
  and delete the old state last, since leftover state misleads.
  Bound how long the system sits in a delicate dual state.
- **Check both sides while they coexist.**
  During a cutover, run smoke tests against old and new endpoints continuously,
  not once at the switch.
- **Observe before acting.**
  Run new automation in recommend-only mode before it changes anything,
  and watch for two controllers fighting over a resource.
- **Roll back first, investigate second.**
  Restore the last good version, then root-cause from the logs.
  Document the fast rollback path before you need it.
- **Do the painful operation often.**
  A deploy or upgrade on a fixed cadence becomes routine;
  a rare one stays hard and catches people unprepared.
- **Schedule risky changes when help is around:** business hours,
  the teams you depend on reachable, not before a holiday.
- **Expect second-order effects from your own change.**
  Concentrating load to save cost, for instance,
  raises the cost of everything that scales with per-instance traffic;
  plan to re-tune after.
