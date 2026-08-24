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

## A Unit's Environment Is Not a Login's

A user unit always has `XDG_RUNTIME_DIR`; an sshd login frequently does not. A
tool that derives a path from it therefore resolves somewhere different depending
on which side started it, and neither side can see the other's state. Zellij is
the worked example: it keys session sockets off `$XDG_RUNTIME_DIR` and falls back
to `/tmp/zellij-$UID`, so a unit and the login it exists to serve build two
separate sessions of the same name and each reports the other missing.

Pin such a variable explicitly on both sides rather than letting each inherit
whatever its context happens to supply. The same applies to `PATH`, which a unit
does not inherit from a login shell at all, so spell it out when `ExecStart`
resolves a tool through a version manager's shims.

## User Units at Boot Need Lingering

`WantedBy=default.target` starts a unit when the *user manager* starts, which
without lingering is at first login rather than at boot. A service meant to be up
on a machine nobody has logged into needs `loginctl enable-linger <user>`, and
the failure is quiet: the unit is enabled, the file is correct, and nothing is
running. Lingering also keeps `/run/user/$UID` present between logins, so
anything resolving `XDG_RUNTIME_DIR` depends on it too.

Treat it as a precondition to confirm (`loginctl show-user <user> -p Linger`)
rather than to assume, especially on an image that may have set it for you.

## `uv run` in a Long-Lived Unit

A `uv run` process holds a shared lock on the uv cache (`~/.cache/uv/.lock`) for
its entire lifetime, not only while it resolves and installs.
A unit that runs one therefore blocks `uv cache prune` on that machine for as
long as the service is up, and prune waits rather than failing.

For a script with no dependencies, pass `--no-cache` wherever that `uv run` is
written, in `ExecStart` or in the script's own shebang.
It builds the environment under `/tmp` and takes no shared lock, at the cost of
rebuilding a bare venv on each start.
Where the service has dependencies, `--no-cache` would re-download them every
start, so install them into a real venv (`uv sync`) and point `ExecStart` at that
venv's own entry point rather than at `uv run`.

Reaching for `uv cache prune --force` to get past the wait trades a hang for
corruption: it skips the wait, not the race, deleting in-use cached environments
out from under running processes, which then fail at their next import.
A maintenance job that prunes should bound its wait instead
(`timeout 30 uv cache prune`) and skip the prune while something else is running.

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

## Specifiers Expand in Unit Files, Not in `systemd-run`

`%h` (home), `%U` (uid), and `%l` (short hostname) let a unit avoid naming a
machine or a user, so it survives a rename and needs no interpolation by the
installer that writes it.

Test one with a real unit file. `systemd-run --user ... /bin/sh -c 'echo "%l"'`
prints `%l` verbatim, which reads as "specifiers are not available here" when
the identical `ExecStart` in an installed unit expands it correctly. Reaching
for `systemd-run` as the quick check is what produces the false negative.

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

Whether a restart is *actually* destructive depends on where the spawned process
ended up. A daemon that re-parents itself out of the unit's cgroup keeps running
through `stop` and `restart`, so systemd is not managing its lifetime at all.
Compare `/proc/<pid>/cgroup` against `systemctl show <unit> -p ControlGroup`
instead of assuming either way: assuming systemd reaps it leaves a stray process
behind, and assuming it doesn't means avoiding a restart that was safe.

A oneshot that establishes state rather than performing work wants
`RemainAfterExit=yes`, so the unit reads as active for as long as that state
holds instead of as a job that finished. Where the command treats "already in the
desired state" as an error, `SuccessExitStatus=` is how the unit says otherwise.
Confirm first that genuine failures use a different code: zellij's
`attach --create-background` exits 1 for "Session already exists" and panics with
101 on a real fault, so tolerating 1 there hides nothing.

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
