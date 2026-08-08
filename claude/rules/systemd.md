# systemd

## Running systemctl

`systemctl --user` needs `XDG_RUNTIME_DIR` to find the user bus. A non-login or
non-interactive context (a hook, a provisioning script, a command run over `ssh`)
usually lacks it, and every call then fails with:

```text
Failed to connect to bus: No medium found
```

Set it explicitly rather than assuming the caller's environment carries it:

```bash
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
```

`systemctl start` waits for the operation to finish, which for a `Type=oneshot`
service means the entire job, bounded only by its `TimeoutStartSec`. Pass
`--no-block` to trigger a long-running oneshot and return immediately, or a unit
with a 75 minute timeout holds the caller for 75 minutes.

## Template units

A **template unit** (`name@.service`) is a single file shared by every instance, so
no value that differs between instances can live in it. Instantiate the identical
parts from the template and generate a concrete unit for each part that varies.
Per-instance schedules are the usual case: the service can be `name@.service`, but
each instance needs its own timer file carrying its own `OnCalendar`.

Anything instance-varying in a `Condition*` has to arrive through `%i`, so a
precondition that cannot be written that way belongs in the program the unit runs,
where it can exit cleanly with a diagnostic. A failing condition makes the unit skip
silently, which is indistinguishable from a unit that never fired.

## Generated units

A unit that embeds an absolute path belongs to the installer that knows that path,
so generate it there rather than symlinking it from a repository.

Converge generated units idempotently: write the new text to a temporary file,
compare it against the installed one, and replace only on difference. Run
`daemon-reload` only when something actually changed. Enabling an already-enabled
unit is harmless and needs no guard.

Never restart an active `Type=oneshot` service because its definition changed.
Install the new file, reload, and let the next activation pick it up; restarting
destroys work in progress.

## Validation

- `systemd-analyze verify <unit>` checks a unit file without installing it. It does
  not evaluate `Condition*`, so a passing verify says nothing about whether a
  unit's conditions will hold at runtime.
- `systemd-analyze calendar '<expr>'` prints the normalized expression and the next
  elapse. It is the cheapest way to confirm a schedule means what was intended.
- `OnCalendar=` accepts a timezone suffix (`*-*-* 00:00:00 America/Chicago`), so a
  schedule tracking local wall-clock time needs no UTC arithmetic that breaks twice
  a year.
- `Persistent=true` on a timer stores the last trigger time and fires once on
  activation if an elapse was missed while the machine was down.
