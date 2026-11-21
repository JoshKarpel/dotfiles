---
name: operations
description: >
  Alerting and incident follow-up for running services: what to alert on, how to
  keep runbooks beside alerts, how to make failure modes distinguishable, how to
  behave while another team is investigating, and what an incident timeline
  records. MUST be invoked when adding, changing, or reviewing an alert or a
  runbook entry, when working an incident alongside another team, or when
  writing an incident review, postmortem, or timeline.
---

# Operations

## Alerts

- **A signal that's always red can't escalate.** When a check fails on every
  deploy, nobody can make it louder; fix the noise before alerting on it.
- **Alert on absence.** A traffic floor catches the total outage that
  error-rate alerts miss, since nothing is erroring.
- **Keep the runbook next to the alert.** Attach each runbook entry to its
  alert definition and generate the runbook from those, so they can't drift.
- **Make failure modes distinguishable.** A client should tell load shedding
  from quota exhaustion by status code. Break metrics out by feature and
  replica, and route severities deliberately between paging and chat.

## During an Incident

- **Don't destroy evidence others are using.** During an incident that needs
  another team, avoid restarts and deletions that could hide the root cause
  from them.

## Incident Follow-Up

- **Record what was seen but not recognized.** A warning someone noticed
  before the incident belongs in the timeline, though nobody connected it.
- **Mark unknowns as unknown.** A timeline entry nobody can reconstruct says
  so rather than guessing.
- **Account honestly for recurrence.** A failure that didn't repeat by luck
  hasn't been fixed; say so.
